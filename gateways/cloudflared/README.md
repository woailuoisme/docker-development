# Cloudflare Tunnel 远程安全隧道最佳实践指南

本项目采用 **Cloudflare Zero Trust 远程托管模式（Token 模式）** 配合本地 **Caddy 统一网关**，实现公网安全穿透、DDOS 防护、自动 SSL 证书以及 Authelia SSO 集中鉴权。

---

## 🏗️ 架构流向拓扑

```text
[ 公网用户访问 (https://*.example.com) ]
                  │
                  ▼
[ Cloudflare Edge (WAF / DDoS 防护 / 边缘 CDN) ]
                  │
                  ▼ (QUIC / HTTP2 穿透加密隧道)
[ cloudflare-tunnel 容器 (仅接入 frontend 网络) ]
                  │
                  ▼ (内网 HTTP 明文转发)
[ caddy 网关容器 (http://caddy:80) ]
        ├── Authelia SSO 身份拦截
        ├── 访问日志审计 & 压缩
        └── 按子域名精准分发
                  │
        ┌─────────┼─────────┬─────────┐
        ▼         ▼         ▼         ▼
    [Directus] [Gotify] [MinIO]  [Laravel...]
```

---

## 🚀 极简配置流程（只需 3 步）

### 第一步：获取 Tunnel Token 并填入 `.env`

1. 登录 [Cloudflare Zero Trust 控制台](https://one.dash.cloudflare.com/)。
2. 导航至 **Networks** ➔ **Tunnels** ➔ 点击 **Add a tunnel**（选择 **Cloudflared**）。
3. 为 Tunnel 命名（例如 `docker-dev-tunnel`）并保存。
4. 在安装命令区域，选择 **Docker**，复制命令末尾的 **Token 字符串**（即 `--token` 后面的长字符串）。
5. 打开项目根目录的 `.env` 文件，填入该 Token：

```dotenv
### CLOUDFLARE TUNNEL #####################################
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoi...（你的Token）
```

---

### 第二步：在 Cloudflare 控制台配置泛解析（一次配置，终身免改）

在刚才创建的 Tunnel 页面中，点击 **Public Hostname** 标签页 ➔ **Add a public hostname**：

| 配置项 | 填写内容 | 说明 |
| :--- | :--- | :--- |
| **Subdomain** | `*` | 匹配所有子域名（泛解析） |
| **Domain** | `yourdomain.com` | 选择您在 Cloudflare 托管的主域名 |
| **Path** | *留空* | 匹配所有路径 |
| **Type** | `HTTP` | 隧道内部使用 HTTP 转发 |
| **URL** | `caddy:80` | 直接将流量发给同网络下的 `caddy` 容器 |
| **Additional application settings** ➔ **HTTP Host Header** | *留空 / Preserve* | 保持客户端原始请求的 Host 头部 |

> 💡 **为什么推荐泛解析？**
> 这样配置后，所有 `*.yourdomain.com` 流量都会自动通过隧道进入本地 `caddy` 网关。后续新增或删除任何微服务，**完全不需要再登录 Cloudflare 操作**，直接修改本地 `gateways/caddy/Caddyfile` 即可！

---

### 第三步：启用并启动服务

1. 在根目录 `docker-compose.yml` 的 `include:` 列表中取消注释：

```yaml
include:
  - gateways/docker-compose.yml
  - iam/docker-compose.yml
```

2. 启动服务：

```bash
docker compose up -d cloudflare-tunnel
```

---

## 📦 日常业务服务接入规范

新增 Docker 服务需要公网反代时，仅需两步：

### 1. 确保业务容器加入 `frontend` 网络

在业务服务的 `docker-compose.yml` 中声明 `frontend` 网络（使 Caddy 可以访问它）：

```yaml
services:
  my-app:
    container_name: my-app
    # ...
    networks:
      - frontend
      - backend
```

### 2. 在 `gateways/caddy/Caddyfile` 中增加一行路由规则

打开 `gateways/caddy/Caddyfile` 添加反代指令：

* **场景 A：公开 Web 应用**

  ```caddyfile
  import proxy-app app.{$SITE_ADDRESS} my-app:8080
  ```

* **场景 B：受 Authelia 2FA/SSO 保护的私密后台**

  ```caddyfile
  import proxy-app-auth admin.{$SITE_ADDRESS} my-app:8080
  ```

* **场景 C：PHP Laravel 常驻内存应用**

  ```caddyfile
  import proxy-octane-app-auth api.{$SITE_ADDRESS} php-roadrunner:8001 /var/www/lunchbox/public
  ```

### 3. 热重载 Caddy

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## 🛠️ 运维与健康检查

### 1. 查看隧道连接状态与日志

```bash
docker compose logs -f cloudflare-tunnel
```

### 2. 容器内置健康检查

本配置已在容器内开启 `--metrics 0.0.0.0:2000`，并通过 Docker 原生 Healthcheck 定期探测隧道就绪状态：

```bash
# 查看容器健康状态 (healthy / unhealthy)
docker inspect --format='{{json .State.Health.Status}}' cloudflare-tunnel
```
