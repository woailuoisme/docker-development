# OpenBao 安全凭据与动态密钥管理基础设施

OpenBao（Linux 基金会托管项目，基于 HashiCorp Vault 1.14 构建的开源分支，遵循 MPL-2.0 协议）是为现代云原生、微服务及研发环境量身打造的企业级敏感数据管理与加密即服务（EaaS）基础设施。

---

## 🌟 核心特性与架构设计

1. **Raft 集成存储引擎 (Integrated Storage)**：
   - 弃用已被废弃的 `file` 存储后端，采用高可靠的嵌入式 Raft 状态机协议，直接在本地磁盘进行数据复制与状态维护，无需依赖外部 Consul 或数据库。
2. **防内存交换敏感锁定 (`IPC_LOCK`)**：
   - 容器挂载 Linux `IPC_LOCK` 权能，确保内存中解密的明文密钥绝不换出至操作系统 Swap 磁盘空间。
3. **内置现代化 Web UI 控制台**：
   - 原生开启 Web 界面，访问 `https://bao.{$SITE_ADDRESS}/ui` 或 `http://localhost:8200/ui` 即可直观操作。
4. **多网络拓扑隔离**：
   - 同时接入 `frontend`（用于前置 Caddy 网关统一反代）与 `backend`（用于微服务和数据库间安全内网通信）。

---

## 📂 目录与持久化规范

```text
iam/open-bao/
├── docker-compose.yml       # OpenBao 容器服务编排定义
├── config/
│   └── openbao.hcl          # 核心声明式配置文件 (Raft、监听器、UI、TTL)
├── manage.sh                # 运维、初始化、解封与交互管理脚本 (已授权可执行)
└── README.md                # 模块文档说明
```

数据持久化路径遵循全局 `AGENTS.md` 规范：

- **核心数据存储**：`${DATA_PATH}open-bao/data`（存储加密密文与 Raft 日志）
- **配置文件挂载**：`${CONFIG_PATH}iam/open-bao/config/openbao.hcl`
- **审计运行日志**：`${LOG_PATH}open-bao`

---

## 🚀 快速上手指南

### 1. 启动 OpenBao 服务

确保在 `iam/docker-compose.yml` 中已启用 `open-bao/docker-compose.yml`，然后执行：

```bash
docker compose up -d open-bao
```

### 2. 初始化与解封集群 (首次运行必须)

OpenBao 出于绝对安全模型考量，新集群启动后处于封锁（Sealed）状态，需进行初始化以获取主解封密钥与根 Token：

```bash
# 执行一键初始化（自动将凭据保存在本地 iam/open-bao/.keys.json 并设置 0600 权限）
./iam/open-bao/manage.sh init

# 执行节点解封（自动读取 .keys.json 中的密钥）
./iam/open-bao/manage.sh unseal

# 查看当前运行健康与解封状态
./iam/open-bao/manage.sh status
```

### 3. 登录并测试凭据存取

可以通过快捷脚本直接代理 CLI 指令（已自动注入环境变量与 Token）：

```bash
# 启用 KV 第 2 版机密引擎 (默认挂载于 secret/)
./iam/open-bao/manage.sh cli secrets enable -version=2 kv

# 写入一条敏感数据
./iam/open-bao/manage.sh cli kv put secret/my-app db_password="SuperSecretPassword123" api_key="sk-live-xyz"

# 读取敏感数据
./iam/open-bao/manage.sh cli kv get secret/my-app
```

---

## 🌐 Caddy 网关反代接入

在 `gateways/caddy/Caddyfile` 中已预留 OpenBao 反向代理规则：

```caddyfile
import proxy-app-auth bao.{$SITE_ADDRESS} open-bao:8200
```

启用后，通过浏览器访问 `https://bao.test.local/ui/`，即可在 Authelia 统一身份认证保护下登录使用 OpenBao Web 控制台。

---

## 💡 开发调试模式 (Dev Mode)

如果仅需快速进行单元测试或临时调试，无需 Raft 持久化与解封流程，可执行：

```bash
# 启动内存 Dev 模式临时容器（默认根 Token 为 root，按 Ctrl+C 退出销毁）
./iam/open-bao/manage.sh dev
```
