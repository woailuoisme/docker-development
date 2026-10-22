# Semaphore UI (现代开源自动化运维控制台与 UI)

本项目基于开源的自动化运维与 CI/CD 编排平台 [Semaphore UI](https://github.com/semaphoreui/semaphore)（原 Ansible Semaphore，官方镜像 `semaphoreui/semaphore:latest`），为本开发与生产环境提供直观、安全、开箱即用的 Ansible Playbook、Terraform、OpenTofu、Bash 与 PowerShell 可视化调度与执行平台。

---

## 🌟 核心特性与优势

- **多运维工具统一编排**：原生支持 Ansible、Terraform、OpenTofu、Bash 脚本及 PowerShell，提供统一的 UI 画布与 API 控制。
- **内置完整 Ansible 运行环境**：官方镜像内置 `ansible` 与 `ansible-core`，开箱即用，无需额外在宿主或构建层安装工具链。
- **凭据与秘钥集中托管**：安全存储 SSH 私钥、主机密码与第三方 API 凭证，在任务执行时动态且安全地注入环境。
- **多任务工作流编排（Workflows）**：支持图形化定义流水线步骤、分支逻辑与手动确认审批关卡（Approval Gates）。
- **极简数据持久化**：默认采用嵌入式 **SQLite** 本地单文件存储，零外部数据库依赖；亦支持无缝接入生产级外部 PostgreSQL 或 MySQL。

---

## 🏗️ 端口与持久化规范

### 1. 服务端口

| 协议 / 服务 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **HTTP Web / API** | `3000` | `3000:3000` | Web 仪表盘控制台与 RESTful API 接口（亦可通过 Caddy 反代） |

### 2. 持久化数据路径

数据持久化遵从项目 `AGENTS.md` 规范，统一挂载至宿主机 `${DATA_PATH}`：

| 宿主机路径 | 容器内挂载路径 | 说明 |
| :--- | :--- | :--- |
| `${DATA_PATH}semaphore/data` | `/var/lib/semaphore` | 存放 SQLite 数据库文件（`database.sqlite`）与系统运行数据 |
| `${DATA_PATH}semaphore/tmp` | `/tmp/semaphore` | 存放任务执行时克隆的 Git 仓库与临时 Playbook 缓存 |

---

## 🚀 快速启动

### 1. 启用模块化编排

在根目录 `docker-compose.yml` 中确认已引入 `devtools`：

```yaml
include:
  # ...
  - devtools/docker-compose.yml
```

并在 `devtools/docker-compose.yml` 中取消注释 `semaphore`：

```yaml
include:
  # ...
  - semaphore/docker-compose.yml
```

### 2. 启动服务

```bash
docker compose up -d semaphore
```

启动完成后，可直接访问：

- 本地直连：`http://localhost:3000`
- 反向代理（若已配置 Caddy）：`https://semaphore.{$SITE_ADDRESS}`
- 默认管理员账号：`admin` / `changeme`（可在首次登录后于控制台后台修改）

---

## ⚙️ 接入外部 PostgreSQL 数据库（可选）

如需将 SQLite 切换为项目现有的 PostgreSQL 数据库，在 `devtools/semaphore/docker-compose.yml` 中修改并取消注释对应环境变量：

```yaml
environment:
  - SEMAPHORE_DB_DIALECT=postgres
  - SEMAPHORE_DB_HOST=postgres
  - SEMAPHORE_DB_PORT=5432
  - SEMAPHORE_DB_USER=${POSTGRES_USER}
  - SEMAPHORE_DB_PASS=${POSTGRES_PASSWORD}
  - SEMAPHORE_DB=semaphore
```
