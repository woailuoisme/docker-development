# n8n (现代化开源工作流自动化与 AI Agent 编排平台)

本项目基于开源的工作流自动化平台 [n8n](https://github.com/n8n-io/n8n)（官方镜像 `docker.n8n.io/n8nio/n8n`），为本开发与生产环境提供强大的低代码/无代码自动化编排与 AI 智能体应用基础设施。

---

## 🌟 核心特性与优势

- **丰富的节点生态**：内置 400+ 开箱即用的第三方 SaaS 服务、数据库、协议与中间件集成节点。
- **先进的 AI Agent 编排**：原生集成 LangChain 工具链，支持 OpenAI、Anthropic、Ollama、Qdrant 等大模型与向量数据库，轻松搭建具备记忆、推理与工具调用能力的智能体工作流。
- **隐私与数据自主**：私有化部署，数据全本地留存，零外部依赖，极易随数据卷快照迁移或备份。
- **开箱即用 SQLite / 无缝切换 PostgreSQL**：默认单文件嵌入式存储，零额外安装成本；亦支持无缝接入项目现有的 PostgreSQL 数据库以应对大规模并发执行。
- **可视化 Web 界面**：直观的连线画布、实时执行历史追踪、Webhook 调试与 Cron 定时触发调度。

---

## 🏗️ 端口与持久化规范

### 1. 服务端口

| 协议 / 服务 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **HTTP Web / API** | `5678` | `5678:5678` | n8n 控制台画布界面、Webhook 入口与 API 接口 |

### 2. 持久化数据路径

数据持久化遵从项目 `AGENTS.md` 规范，统一挂载至宿主机 `${DATA_PATH}`：

| 宿主机路径 | 容器内挂载路径 | 说明 |
| :--- | :--- | :--- |
| `${DATA_PATH}n8n` | `/home/node/.n8n` | 存放工作流配置、凭证密钥及内置 SQLite 数据库文件 |

> [!NOTE]
> **关于 Docker 具名卷（Named Volume）**：  
> 若希望使用 Docker 原生具名卷（例如 `docker volume create n8n_data` 进行本地测试隔离），可将 `docker-compose.yml` 中的卷挂载替换为 `n8n_data:/home/node/.n8n`，并取消文件底部 `volumes:` 块声明。

---

## 🚀 快速启动

### 1. 启用模块化编排

在根目录 `docker-compose.yml` 中确认已引入 `apps`：

```yaml
include:
  # ...
  - apps/docker-compose.yml
```

并在 `apps/docker-compose.yml` 中取消注释 `n8n`：

```yaml
include:
  # ...
  - n8n/docker-compose.yml
```

### 2. 启动服务

```bash
docker compose up -d n8n
```

启动完成后，可直接访问：

- 本地直连：`http://localhost:5678`
- 反向代理（若已配置 Caddy）：`https://n8n.{$SITE_ADDRESS}`

---

## ⚙️ 接入外部 PostgreSQL 数据库（可选）

如需将 SQLite 切换为生产级 PostgreSQL，在 `apps/n8n/docker-compose.yml` 中取消注释对应环境变量：

```yaml
environment:
  - DB_TYPE=postgresdb
  - DB_POSTGRESDB_HOST=postgres
  - DB_POSTGRESDB_PORT=5432
  - DB_POSTGRESDB_DATABASE=n8n
  - DB_POSTGRESDB_USER=${POSTGRES_USER}
  - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
```
