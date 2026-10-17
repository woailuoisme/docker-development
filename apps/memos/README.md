# Memos (现代化私有轻量级碎片化知识库与便签笔记)

本项目基于开源的高颜值碎片化笔记与卡片式知识库服务 [Memos](https://github.com/usememos/memos)（由 Go + React 开发），为本开发与生产环境提供极简、安全、数据自主的私有灵感便签与日常备忘录基础设施。

---

## 🌟 核心特性与优势

- **极简卡片便签设计**：专注于快速捕捉灵感与思考碎片，支持标准 Markdown 语法、代码高亮、标签分类（`#标签`）、双链引用与多附件直接上传。
- **数据隐私与绝对自主**：默认采用嵌入式 **SQLite** 本地单文件存储，无额外依赖、无遥测追踪，极易随数据卷快照迁移或定时备份。
- **多维度视图与社交分享**：
  - 支持类似 GitHub 的年度打卡与活动热力图统计。
  - 支持笔记公开/私有权限精细化控制、独立便签链接对外分享与标准 RSS 订阅源输出。
- **多端生态与丰富客户端**：响应式 Web 界面完美适配桌面与手机浏览器；开放完备的 RESTful API 与 gRPC 接口，支持 iOS / Android 端第三方客户端（如 Moe Memos）及浏览器扩展快捷记录。
- **可横向扩展存储架构**：支持开箱即用 SQLite，亦可通过环境变量无缝切换至高可用外部 PostgreSQL 或 MySQL。

---

## 🏗️ 端口与持久化规范

### 1. 服务端口

| 协议 / 服务 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **HTTP Web / API** | `5230` | `5230:5230` | Web 界面与 RESTful API 访问入口（可通过 Caddy 反代） |

### 2. 持久化数据路径

数据持久化遵从项目 `AGENTS.md` 规范，统一存储于宿主机 `${DATA_PATH}`：

| 宿主机路径 | 容器内挂载路径 | 说明 |
| :--- | :--- | :--- |
| `${DATA_PATH}memos` | `/var/opt/memos` | 存放 SQLite 数据库文件（`memos_prod.db`）与上传的图片/文件资源 |

---

## 🚀 快速启动

### 1. 启用模块化编排

在根目录 `docker-compose.yml` 中确认已引入 `apps`：

```yaml
include:
  # ...
  - apps/docker-compose.yml
```

并在 `apps/docker-compose.yml` 中取消注释 `memos`：

```yaml
include:
  # ...
  - memos/docker-compose.yml
```

### 2. 启动服务

```bash
docker compose up -d memos
```

查看运行日志：

```bash
docker compose logs -f memos
```

---

## 🔑 初始管理员注册与安全配置

1. **初始注册**：服务启动后，在浏览器访问 `http://localhost:5230`（或反代域名）。
2. **所有者创建**：首次注册的第一个账户将自动成为系统的超级管理员（**Host**）。
3. **关闭公开注册**：为了防止公网被未授权人员注册占用，建议管理员登录后前往「**设置 (Settings)**」→「**系统 (System)**」关闭「**允许用户注册 (Allow user signup)**」。

---

## 🌐 网关反向代理接入 (Caddy)

如需通过 Caddy 网关将 Memos 暴露为安全的 HTTPS 独立子域名：

在 `gateways/caddy/Caddyfile` 中取消注释如下规则：

```caddyfile
import proxy-app memos.{$SITE_ADDRESS} memos:5230
```

重载 Caddy 规则生效：

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## ⚙️ 外部数据库扩展 (可选)

若需要使用外部 PostgreSQL（如共享本项目的 `postgres` 服务），可将 `apps/memos/docker-compose.yml` 中的数据库配置取消注释：

```yaml
environment:
  - TZ=${TIMEZONE:-Asia/Shanghai}
  - MEMOS_DRIVER=postgres
  - MEMOS_DSN=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/memos?sslmode=disable
```
