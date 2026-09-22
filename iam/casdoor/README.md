# Casdoor 身份认证与单点登录平台

Casdoor 是开源的 OAuth 2.0 / OIDC 身份认证与访问管理平台（Casbin 团队维护），提供用户与组织管理、应用接入、多协议登录（OAuth 2.0 / OIDC / SAML / CAS / LDAP / RADIUS）以及 Web 管理控制台。

---

## 🧩 部署形态与依赖

- **镜像**：`casbin/casdoor:4.2.0`，单容器，监听容器内 `8000`（配置见 `conf/app.conf` 的 `httpport`）。
- **数据库**：复用仓库共享 PostgreSQL（`database/postgres-18` 的 `postgres` 容器），库名 `casdoor`。
  该库由 `database/postgres-18/docker-entrypoint-initdb.d/00-createdb.sh` 中的
  `create_db_if_not_exists "casdoor"` 创建 —— **仅在 Postgres 首次初始化（数据目录为空）时执行**。
- **缓存**：当前未接入 Redis（`app.conf` 的 `redisEndpoint` 为空，走进程内存缓存）。
- **网络**：同时接入 `frontend`（供 Caddy 反代）与 `backend`（访问共享 Postgres）。
- **默认状态**：`iam/docker-compose.yml` 中该服务的 include **处于注释态**，按需启用。

---

## 📂 目录与挂载

```text
iam/casdoor/
├── docker-compose.yml   # 服务编排定义
├── conf/
│   └── app.conf         # Casdoor 核心配置（端口、数据库 DSN、日志策略、协议端口）
└── README.md            # 本文档
```

挂载路径遵循全局 `AGENTS.md` 规范：

| 容器内路径 | 宿主机路径 | 用途 |
| :--- | :--- | :--- |
| `/conf` | `${CONFIG_PATH}iam/casdoor/conf` | 配置文件目录（读写，Casdoor 会回写 `app.conf`） |
| `/logs` | `${LOG_PATH}casdoor` | 运行日志（`app.conf` 的 `logConfig` 指向 `logs/casdoor.log`） |

---

## ⚙️ 关键配置说明 (`conf/app.conf`)

| 配置项 | 当前值 | 说明 |
| :--- | :--- | :--- |
| `httpport` | `8000` | 容器内监听端口，对应编排中的 `${CASDOOR_PORT:-8300}:8000` 映射 |
| `runmode` | `prod` | 生产模式（关闭调试输出） |
| `driverName` / `dbName` | `postgres` / `casdoor` | 数据库驱动与库名 |
| `dataSourceName` | 指向 `host=postgres port=5432` | PostgreSQL 连接串 |
| `initDataFile` | `./init_data.json` | 首次启动用镜像内置初始化数据建组织与管理员 |
| `logConfig` | `filename: logs/casdoor.log` | 与 `${LOG_PATH}casdoor` 挂载对应 |
| `ldapServerPort` / `radiusServerPort` | `389` / `1812` | LDAP / RADIUS 协议端口，**编排未发布**，需要时自行加端口映射 |

---

## 🚀 启用与访问

### 1. 启用服务

取消 `iam/docker-compose.yml` 中 `# - casdoor/docker-compose.yml` 的注释，然后：

```bash
docker compose up -d casdoor
docker compose ps casdoor          # 状态应为 healthy（探活 /api/health）
```

若 `${DATA_PATH}postgres18` 已存在（非首次初始化），需手工补建数据库：

```bash
docker exec postgres psql -U postgres -c 'CREATE DATABASE casdoor;'
```

### 2. 访问入口

- **Web 控制台**：`http://localhost:${CASDOOR_PORT:-8300}`（默认 `8300`，可在 `.env` 中设 `CASDOOR_PORT` 覆盖）
- **健康检查**：`curl -f http://localhost:8300/api/health`
- **首次登录**：按镜像内置 `init_data.json` 初始化组织与管理员（官方默认管理员为 `admin` / `123`，请以实际登录页为准，**登录后立即改密**）。

### 3. Caddy 反代

`gateways/caddy/Caddyfile` 中**尚未包含 Casdoor 规则**，需要时按既有模板添加：

```caddyfile
# 管理控制台建议带鉴权（Authelia），对外提供 OIDC 时再按需放开
import proxy-app-auth casdoor.{$SITE_ADDRESS} casdoor:8000
```

---

## 🔧 常用运维指令

```bash
# 查看日志（容器内日志文件同时落在 ${LOG_PATH}casdoor）
docker compose logs -f casdoor
tail -f "${LOG_PATH}casdoor/casdoor.log"

# 校验数据库连通与表结构是否已建
docker exec postgres psql -U postgres -d casdoor -c '\dt' | head

# 重启使 app.conf 变更生效
docker compose restart casdoor
```

---

## ⚠️ 注意事项

1. **`app.conf` 中的数据库口令为明文且已随仓库分发**（`dataSourceName` 里的 `password=...`，与 `.env` 的 `POSTGRES_PASSWORD` 同值）。
   建议：轮换该口令，并把配置改为运行时生成/注入（例如模板化 DSN、或在 `.gitignore` 下维护本地 `app.conf`）。
2. **`/conf` 为读写挂载**（编排中未加 `:ro`）：如需收紧为只读，改配置时记得临时放开，否则配置变更无法落盘。
3. **LDAP / RADIUS 未发布端口**：`app.conf` 已配 `389` / `1812`，但编排只映射了 Web 端口；启用这些协议需自行添加 `ports`（并注意 389/636 属特权端口）。
4. **依赖共享 Postgres**：`postgres` 未启用时 `casdoor` 会因依赖缺失而无法启动（该服务在 `database/docker-compose.yml` 中默认启用）。
