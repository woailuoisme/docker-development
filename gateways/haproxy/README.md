# HAProxy 3.4 企业级生产网关与负载均衡

基于官方 `haproxy:3.4-alpine` 镜像构建的高性能、工业生产级 TCP/HTTP 反向代理与负载均衡器。

## 架构与核心特性

- **轻量与安全基底**：基于 Alpine Linux，内置 `bash`、`curl`、`openssl`、`tzdata`，运行时严格以非 root 用户 `haproxy:haproxy` 运行。
- **Nginx 式模块化与 include 支持**：
  - **`include <pattern>` 语法支持**：支持类似 Nginx `include /etc/nginx/conf.d/*.conf;` 的配置拆分，主配置末尾自动引入 `conf.d/*.cfg`。
  - **环境变量动态模板替换**：所有主配置、`conf.d/*.cfg` 与 `maps/*.map` 原生支持 `${SITE_ADDRESS}`（以及 `${SITE_ADDRESS:-test.local}` 与 `{$SITE_ADDRESS}`）环境变量自动替换，环境迁移无需硬编码域名。
  - **动态域名路由表 (`maps/hosts.map`)**：类似 Nginx `server_name` 与 Caddy 站点映射，通过 `map_dom` 实现 Host 与后端解耦，添加站点无需重构主前端。
  - **微服务解耦**：可在 `conf.d/` 中为每个微服务定义独立的 `backend`（如 `backends.cfg`、`octane.cfg`、`garage.cfg`）。
- **工业级生产安全加固与防护**：
  - **Stick-Table 智能限流与防 CC**：基于内存统计表追踪客户端 IP，限制单 IP 并发连接 ≤50、10s 频次 ≤200 次，超限阻断并返回 `429 Too Many Requests`；内网及私网网段 (`127.0.0.1`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) 自动加入白名单全豁免。
  - **服务器指纹剥离 (Server Cloaking)**：自动抹除 `Server` 和后端泄露的 `X-Powered-By` 头，防止攻击者嗅探 HAProxy 或语言框架版本。
  - **现代安全响应头 (OWASP & Mozilla Modern)**：全面启用 HSTS、`X-Content-Type-Options: nosniff`、`X-Frame-Options: SAMEORIGIN`、`Referrer-Policy: strict-origin-when-cross-origin` 与 `Permissions-Policy`。
  - **恶意方法拦截**：自动阻断 `TRACE` 与 `TRACK` 嗅探请求 (403 Forbidden)。
  - **8404 管理端点权限隔离**：Web 看板强制 HTTP Basic Auth 认证 (账号密码由环境变量注入)，同时放行 `/metrics` 供内网 Prometheus / 监控采集器直接免密拉取。

## 目录与持久化挂载

| 宿主机路径 (环境变量) | 容器内挂载路径 | 说明 |
| :--- | :--- | :--- |
| `./haproxy.cfg` | `/usr/local/etc/haproxy/haproxy.cfg:ro` | 核心配置文件 (支持 `include`) |
| `./conf.d` | `/usr/local/etc/haproxy/conf.d:ro` | 模块化后端配置目录 |
| `./maps` | `/usr/local/etc/haproxy/maps:ro` | 域名与后端映射表目录 |
| `${DATA_PATH}ssl` | `/etc/haproxy/ssl:ro` | Lego 生成的 ACME 证书源目录 |
| `${DATA_PATH}haproxy/certs` | `/etc/haproxy/certs` | HAProxy 激活的合并 PEM 证书库 |
| `${DATA_PATH}haproxy` | `/var/lib/haproxy` | 编译后配置、运行时状态与 Admin Socket |

## 端口规划

- `80`：HTTP 统一接入入口（强制 301 重定向到 HTTPS，保留 ACME 验证通道）
- `443`：HTTPS 统一接入入口（TLS 终止、HTTP/2、业务反代）
- `8404`：状态管理面板与 `/metrics` Prometheus 端点

## 配合 Lego 自动化证书使用

在项目 `.env` 中配置：

```env
# 指定 Lego 签发后重载 HAProxy (支持逗号分隔多个容器)
LEGO_RELOAD_CONTAINER=haproxy
```

启动流程：

```bash
# 1. 启动 Lego 自动申请/续期证书 (基于 Cloudflare / 阿里云等 DNS 校验)
docker compose up -d lego

# 2. 启动 HAProxy 网关
docker compose up -d haproxy
```

## 运维与管理命令 (类似 Nginx + 运行时 API)

```bash
# 1. 检查配置文件语法 (类似于 nginx -t)
docker compose exec haproxy haproxy-check

# 2. 重新编译并平滑热重载 (类似于 nginx -s reload)
docker compose exec haproxy haproxy-reload

# 3. 通过内置 Runtime API 执行动态指令 (无需重载即可查询/调控)
docker compose exec haproxy haproxy-cli show info
docker compose exec haproxy haproxy-cli show stat
docker compose exec haproxy haproxy-cli "show map /var/lib/haproxy/maps/hosts.map"
docker compose exec haproxy haproxy-cli "show table st_src_ip"

# 4. 通过 Docker 发送 HUP 信号触发平滑热重载
docker compose kill -s HUP haproxy

# 5. 查看 Prometheus 采集指标 (无需认证) 与 Web 监控看板 (Basic Auth 认证)
curl -s http://localhost:8404/metrics | head -n 30
curl -s -u admin:admin http://localhost:8404/
```
