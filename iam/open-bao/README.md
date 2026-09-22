# OpenBao 安全凭据与动态密钥管理基础设施

OpenBao（Linux 基金会托管项目，基于 HashiCorp Vault 1.14 构建的开源分支，遵循 MPL-2.0 协议）是面向云原生与研发环境的企业级敏感数据管理与加密即服务（EaaS）基础设施。本模块以**单容器**形态运行服务端，全部密钥数据落在本地 Raft 存储中。

---

## 🌟 核心特性与架构设计

1. **Raft 集成存储引擎 (Integrated Storage)**：
   - 弃用已被废弃的 `file` 存储后端，采用嵌入式 Raft 状态机协议，直接在本地磁盘维护数据与一致性状态，无需外部 Consul 或数据库。
   - 使用 Raft 时 `cluster_addr` 为**必填**（缺失会直接启动失败）。
2. **内存与 Swap 加固**：
   - OpenBao 已**移除 mlock 支持**：配置里写 `disable_mlock` 会导致启动失败（镜像会明确报错），编排因此也不再需要 `IPC_LOCK` 权能。
   - 官方替代做法是在宿主机层面关闭或加密 Swap，见 <https://openbao.org/docs/install/#post-installation-hardening>。
3. **内置现代化 Web UI 控制台**：
   - `ui = true`，访问 `https://bao.{$SITE_ADDRESS}/ui` 或 `http://localhost:8200/ui`。
4. **多网络拓扑隔离**：
   - 同时接入 `frontend`（供 Caddy 统一反代）与 `backend`（内部服务与数据库通信）。
5. **TLS 卸载**：监听器 `tls_disable = 1`，容器间走内网明文，外部 HTTPS 由 Caddy 网关统一接管。

---

## 📂 目录与持久化规范

```text
iam/open-bao/
├── docker-compose.yml       # 单容器服务编排（仅服务端）
├── Dockerfile               # 基于官方镜像烘焙配置与健康检查
├── config/
│   ├── openbao.hcl          # 核心声明式配置 (Raft、监听器、UI、租赁 TTL、审计设备)
│   └── policies/            # 应用侧最小权限策略 (app-db-ro / app-db-rw)
├── setup.sh                 # 引擎、动态凭据与 AppRole 的幂等供给脚本
└── README.md                # 模块文档
```

| 宿主机路径 | 容器内路径 | 用途 |
| :--- | :--- | :--- |
| `${DATA_PATH}open-bao/data` | `/openbao/file` | Raft 数据与一致性状态 |
| `${LOG_PATH}open-bao` | `/openbao/logs` | 审计/日志落盘目录 |

> **配置与健康检查都在镜像里**：`config/openbao.hcl` 由 Dockerfile 烘焙到 `/openbao/config/openbao.hcl`，healthcheck 也内联在镜像中，因此编排只保留运行期必需的数据卷、端口与资源限制。**改动 `config/openbao.hcl` 后需重新构建**：`docker compose up -d --build open-bao`。
>
> **配置加载方式**：镜像 entrypoint 在收到 `server` 子命令时会自动追加 `-config=/openbao/config`，因此编排里只需 `command: ["server"]`，无需手写 `-config` 参数。
>
> **文件属主**：容器以镜像默认用户 `openbao`（uid 100 / gid 1000）运行；配置以 `--chown=100:1000` 烘焙，运行期两个挂载点由 entrypoint 尝试 `chown` 给该用户。在 Linux 宿主机上若目录属主为 root，需先执行 `sudo chown -R 100:1000 ${DATA_PATH}open-bao ${LOG_PATH}open-bao`（否则 entrypoint 的 chown 会失败并中断启动）。
>
> **审计设备只能声明式启用**：OpenBao v2.3.2 起禁止经 API/CLI 创建审计设备（报错 `cannot enable audit device via API`），因此审计写在 `openbao.hcl` 的 `audit "file" "to-file"` 块中，在活跃节点重启或收到 `SIGHUP` 时生效（`docker kill -s HUP open-bao` 可免重启应用变更）。

---

## 🚀 快速上手指南

### 1. 启动服务

确保 `iam/docker-compose.yml` 中已启用 `open-bao/docker-compose.yml`，然后：

```bash
docker compose up -d --build open-bao
docker compose ps open-bao          # 未初始化/封存状态下 healthcheck 亦为 healthy
```

### 2. 初始化与解封（首次运行必须）

新集群启动后处于封锁（Sealed）状态，需初始化以获得解封密钥与 Root Token；凭据请立即备份，`iam/open-bao/.keys.json` 已在 `.gitignore` 中：

```bash
# 初始化：凭据直接落盘为本地文件（仅在所有者可读）
docker exec -e BAO_ADDR=http://127.0.0.1:8200 open-bao \
  bao operator init -key-shares=1 -key-threshold=1 -format=json > iam/open-bao/.keys.json
chmod 600 iam/open-bao/.keys.json

# 解封（多份密钥时重复执行至 Unseal Progress 完成）
docker exec -e BAO_ADDR=http://127.0.0.1:8200 open-bao \
  bao operator unseal "$(jq -r '.unseal_keys_b64[0]' iam/open-bao/.keys.json)"

# 查看初始化 / 封锁 / 健康状态
docker exec -e BAO_ADDR=http://127.0.0.1:8200 open-bao bao status
```

### 3. 存取凭据

Root Token 仅用于引导（KV v2 已由 `setup.sh` 在 `secret/` 挂载），静态密钥读写示例：

```bash
TOKEN="$(jq -r '.root_token' iam/open-bao/.keys.json)"

docker exec -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="${TOKEN}" open-bao \
  bao kv put secret/my-app db_password="SuperSecretPassword123"
docker exec -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="${TOKEN}" open-bao \
  bao kv get secret/my-app
```

### 4. 一键供给引擎与访问策略

`setup.sh`（`just bao-setup`）幂等完成引擎、动态凭据与 AppRole 的配置，可反复执行：

```bash
just bao-setup
```

| 层次 | 产出的对象 | 说明 |
| :--- | :--- | :--- |
| 引擎 | `secret/`（KV v2）、`database/` | 已存在则跳过，不会重复挂载 |
| 动态凭据 | `database/config/valkey` + 角色 `app-ro` / `app-rw` | 以 **Valkey** 为目标：插件 `valkey-database-plugin`，连接用 `host/port/tls` 离散参数（无需 `connection_url`），`creation_statements` 是 ACL 规则 JSON |
| 访问控制 | policy `app-db-ro` / `app-db-rw` + AppRole 角色 + `secret_id` | 两者分别只能读取自己的 `database/creds/<role>` 并续租/吊销自家租约 |

产出后可这样取用动态凭据：

```bash
# 管理侧直接读（用 Root Token）
just bao-cli read database/creds/app-rw

# 应用侧：AppRole 换令牌后取凭据（凭据与 role_id/secret_id 见 .approle-credentials.txt）
```

| 角色 | ACL 规则 | 实测表现 |
| :--- | :--- | :--- |
| `app-ro` | `["~*", "+@read", "+@connection"]` | `SET` 被拒：`NOPERM ... has no permissions to run the 'set' command` |
| `app-rw` | `["~*", "+@read", "+@write", "+@connection"]` | `SET` / `GET` / `DEL` 均成功 |

> 动态用户名由插件生成（形如 `V_APPROLE_APP-RW_xxxx_<到期时间戳>`），**不支持用户名自定义**；租约到期后 ACL 用户会被自动删除，应用必须处理续租或重连。

---

## 🌐 Caddy 网关反代接入

`gateways/caddy/Caddyfile` 中已预留规则（默认注释态）：

```caddyfile
import proxy-app-auth bao.{$SITE_ADDRESS} open-bao:8200
```

启用后通过 `https://bao.test.local/ui/` 在 Authelia 统一身份认证保护下访问控制台。

---

## 🔧 生产补强建议

1. **审计设备已声明式启用**：`openbao.hcl` 的 `audit "file" "to-file"` 块把审计日志写到 `/openbao/logs/audit.log`（对应宿主机 `${LOG_PATH}open-bao`）。v2.3.2 起 API/CLI 方式被禁止，改动该块后重建并重启（或 `docker kill -s HUP open-bao`）即可生效，用 `just bao-cli audit list` 核对。
2. **只用 Root Token 做引导**：日常操作与自动化改用带最小权限 policy 的 Token 或 AppRole，Root Token 仅保留在 `.keys.json` 中应急。
3. **自动解封**：单节点场景重启后需要人工 `unseal`；如需免人工，须接入云 KMS 自动解封（属于额外依赖，未纳入本模块）。
4. **宿主 Swap**：按官方建议关闭或加密，替代已被移除的 mlock 保护。
