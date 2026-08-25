@RTK.md

# AGENTS.md - Lunchbox Docker Development Environment

## 📌 项目概述 (Project Overview)

本项目是一套模块化、生产/开发兼顾的 Docker Compose V2 容器化基础设施（基于 `include` 机制解耦）。主要用于 PHP/Laravel (Octane / RoadRunner / FrankenPHP / FPM) 全栈开发、微服务通信、多数据源及常用运维工具链编排。

---

## 🏗️ 架构与服务组织规范 (Architecture & Conventions)

### 1. 根编排与模块化加载

- **根文件**：`docker-compose.yml` 声明核心网络（`frontend`、`backend`）与数据卷，通过 `include:` 引入各子服务的 `docker-compose.yml`。
- **子服务目录**：各独立服务位于单独目录（如 `caddy/`、`postgres-18/`、`vaultwarden/` 等），内部包含对应的 `docker-compose.yml` 及必要配置。

### 2. 子服务 Compose 编写规范

每个子服务的 `docker-compose.yml` 需遵循统一规范：

- **容器命名**：显式指定 `container_name: <service-name>`。
- **网络归属**：
  - 需要外部反向代理访问（接入 Caddy）的服务加入 `frontend`。
  - 服务间内部通信加入 `backend`。
- **持久化路径**：
  - 数据文件统一挂载至 `${DATA_PATH}<service-name>/...`。
  - 配置文件统一挂载至 `${CONFIG_PATH}<service-name>/...`。
  - 日志文件统一挂载至 `${LOG_PATH}<service-name>/...`。
- **重启策略**：默认 `restart: always` 或 `restart: unless-stopped`。

### 3. Caddy 反向代理接入规范

- 网关位于 `caddy/Caddyfile`。
- 新增反代子域名时，使用模板语法：

  ```caddyfile
  import proxy-app <subdomain>.{$SITE_ADDRESS} <service-container-name>:<internal-port>
  ```

- 如需身份鉴权拦截（通过 Authelia），使用 `import proxy-app-auth`。

---

## 🛠️ 常用开发与检测命令 (Commands & Quality Gates)

本项目集成 `justfile`、`lefthook`、`mise` 作为任务和质量检测管理工具：

### 1. 编排与服务管理

```bash
# 校验所有 Compose 配置文件语法与环境变量替换
just lint-compose
# 或直接执行：
docker compose config

# 启动指定服务（及依赖）
docker compose up -d <service-name>

# 重启或重载指定服务
docker compose restart <service-name>
```

### 2. 静态检查与 Lint 工具

在提交代码前或修改配置后，需执行以下检测确保通过 CI/Lefthook 检查：

```bash
# 运行全量代码与配置检查
just lint

# 格式化 Markdown
just fmt

# 检查 Docker Compose 配置
just lint-compose

# 检查 Caddyfile 语法与模板正确性
just lint-caddy

# 检查所有 Shell 脚本规范 (ShellCheck)
just lint-sh

# 检查所有 Dockerfile 规范 (Hadolint)
just lint-docker

# 检查 GitHub Actions 工作流 (actionlint)
just lint-actions

# Markdown 格式与规范检查 (rumdl)
just lint-md
```

---

## ⚙️ 环境变量说明 (Environment Variables)

核心配置定义在 `.env` 中（模板参考 `.env.example`）：

- `SITE_ADDRESS`：基础域名（如开发环境 `test.local`）。
- `DATA_PATH`：持久化数据主目录（如 `./data/` 或 `/var/docker/development/data/`）。
- `CONFIG_PATH`：配置挂载目录（如 `./` 或 `/var/docker/development/`）。
- `LOG_PATH`：日志目录（如 `./logs/` 或 `/var/docker/development/logs/`）。
- `TIMEZONE`：时区（默认 `Asia/Shanghai`）。
- `APP_CODE_PATH`：应用代码宿主机路径。
- `APP_CODE_PATH_CONTAINER`：应用代码容器内挂载路径（默认 `/var/www`）。

---

## 📝 编码与提交规范 (Agent Guidelines)

1. **增删服务流程**：
   - 在子目录创建/修改 `<service>/docker-compose.yml`。
   - 在根目录 `docker-compose.yml` 的 `include:` 列表中按分类添加对应配置路径。
   - 如需暴露 Web 访问，在 `caddy/Caddyfile` 中配置 `import proxy-app` 规则。
   - 运行 `just validate-docker-compose` 验证配置正确性。
2. **格式规范**：
   - YAML 文件使用 **2 空格缩进**，严禁使用 Tab。
   - Shell 脚本必须以 `#!/usr/bin/env bash` 开头并设置 `set -euo pipefail`。
   - Markdown 文档遵循 standard markdownlint 规范，避免 MD036（独立单行加粗代替标题）。
