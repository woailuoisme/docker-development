# Error Pages (统一美化 HTTP 错误页服务)

本项目基于现代化、轻量级、高性能的 [tarampampam/error-pages](https://github.com/tarampampam/error-pages) 错误页服务，为网关反向代理（Traefik、Caddy 等）提供统一且高颜值的定制 HTTP 错误响应页面（4xx、5xx）。

---

## 🌟 特性亮点

- **零外部依赖 & 极低资源开销**：基于 Go 标准库构建，启动亚毫秒级，内存占用仅约几 MB。
- **自动内容协商 (Content Negotiation)**：
  - 浏览器端访问：输出漂亮美观的 HTML 错误视图。
  - API / CLI 客户端调用（携带 `Accept: application/json` 或请求 `.json` 路径）：自动返回语义化 JSON 错误报文。
- **丰富的内置主题模板**：预设 `l7`（Cloudflare 风格，本项目默认）、`ghost`、`noise`、`lost-in-space`、`hacker-terminal`、`connection` 等多种高品质主题。
- **与 Traefik 云原生深度整合**：
  - 支持 Docker Labels 声明式暴露与中间件注册。
  - 支持 Traefik File Provider 动态中间件与服务组合（`chain-basic@file`）。
  - 支持未匹配未知域名的全局兜底拦截（Catch-All Router）。
- **与 Caddy 模板化整合**：提供专属 `proxy-app-errors` 模板，同时处理网关层 502/503 与后端业务应用 4xx/5xx。

---

## 🚀 快速启动

在 `gateways/docker-compose.yml` 中解除注释启用 `error-pages`：

```yaml
include:
  # ...
  - error-pages/docker-compose.yml
```

启动服务：

```bash
docker compose up -d error-pages
```

---

## ⚙️ 核心环境变量说明

| 环境变量 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `TEMPLATE_NAME` | `l7` | 默认 HTML 主题模板（可选：`l7`, `ghost`, `noise`, `lost-in-space`, `hacker-terminal`, `connection`, `app-down`, `shuffle` 等） |
| `SHOW_DETAILS` | `true` | 是否在错误页中展示详细信息（客户端 IP、Trace/Request ID、错误详情等） |
| `DEFAULT_ERROR_PAGE` | `404` | 未指定错误码时的默认返回错误码 |
| `LOG_FORMAT` | `json` | 日志格式（`console` 或 `json`） |
| `LOG_LEVEL` | `info` | 日志级别（`debug`, `info`, `warn`, `error`） |

---

## 🛠️ 网关反代接入指南

### 1. Traefik 接入模式

#### 方式 A：在 Traefik File 动态配置中使用标准链路（推荐）

在 `gateways/traefik/dynamic/middlewares.yml` 中，`error-pages` 已默认注入 `chain-basic@file`。任何挂载基础链路的路由将自动获得美化错误页能力：

```yaml
http:
  routers:
    my-app:
      rule: 'Host(`myapp.{{ env "SITE_ADDRESS" }}`)'
      entryPoints:
        - websecure
      service: my-app-service
      tls: {}
      middlewares:
        - chain-basic@file
```

#### 方式 B：通过 Docker Labels 为其他容器接入

在业务服务的 `docker-compose.yml` 中，添加 Traefik 标签引用 `error-pages-middleware`：

```yaml
services:
  my-service:
    image: my-app:latest
    labels:
      traefik.enable: "true"
      traefik.http.routers.my-service.rule: Host(`myapp.${SITE_ADDRESS}`)
      traefik.http.routers.my-service.entrypoints: websecure
      traefik.http.routers.my-service.tls: "true"
      # 引用 error-pages 定义的中间件 (由 error-pages 容器注册)
      traefik.http.routers.my-service.middlewares: error-pages-middleware@docker
```

#### 方式 C：访问独立预览路由与兜底路由

- **预览路由**：直接在浏览器访问 `https://errors.${SITE_ADDRESS}/404` 或 `https://errors.${SITE_ADDRESS}/502` 查看各状态码渲染效果。
- **兜底捕获（Catch-All）**：当请求未匹配任何已注册的主机名或路径时，Traefik 兜底路由自动捕获并渲染标准 404 页面。

---

### 2. Caddy 接入模式

在 `gateways/caddy/Caddyfile` 中，使用新提供的 `proxy-app-errors` 模板反代业务应用：

```caddyfile
import proxy-app-errors myapp.{$SITE_ADDRESS} myapp-container:8080
```

如需开启独立预览域名：

```caddyfile
import proxy-app errors.{$SITE_ADDRESS} error-pages:8080
```

---

## 🔍 测试与验证

```bash
# 1. 验证 HTML 错误页输出
curl -i https://errors.test.local/404

# 2. 验证 API 内容协商（自动返回 JSON 响应）
curl -i -H "Accept: application/json" https://errors.test.local/502

# 3. 容器健康状态检查
docker inspect --format='{{json .State.Health}}' error-pages
```
