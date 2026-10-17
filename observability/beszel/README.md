# Beszel (轻量级服务器与容器监控看板)

本项目基于开源的高性能服务器与容器监控工具 [Beszel](https://github.com/henrygd/beszel)（基于 Go 与 PocketBase 构建），为单机及分布式多服务器环境提供极简、高颜值、低开销的系统资源可视化监控看板与告警系统。

---

## 🌟 核心特性与优势

- **极度轻量与高性能**：中心端 Hub 基于 Go 与 PocketBase 构建，打包为 `scratch` 极简镜像，单容器常驻内存仅约 **20MB**。
- **直观的监控仪表板**：开箱即用提供 CPU、内存使用率、磁盘可用空间与 I/O 吞吐、网络流量速率、CPU 核心温度图表。
- **Docker 容器全方位监控**：自动识别并实时展示宿主机上所有 Docker 容器的 CPU、内存占用曲线。
- **分布式多节点架构**：
  - **Hub（中心服务端）**：汇总多台服务器指标、存储历史时序数据、提供 Web UI 交互看板与统一告警配置。
  - **Agent（节点探针）**：轻量级探针，安装在需要监控的主机上（单探针仅约 10MB 内存），通过加密认证向 Hub 汇报指标。
- **简单安全的认证连接**：通过公私钥机制与 Token 认证（非对称加密）确保仅授权的探针可以上报数据。
- **灵活的告警通知**：支持通过 Discord、Telegram、Slack、Email、Gotify、Ntfy、Pushover、Webhook 等多渠道推送 CPU/内存/磁盘过载告警。

---

## 🏗️ 端口与持久化规范

### 1. 服务端口

| 协议 / 服务 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **Beszel Hub (Web & API)** | `8090` | `8090:8090` | Web 仪表盘控制台与 REST / WebSocket API 端点 |
| **Beszel Agent (探针监听)** | `45876` | `45876`（Host 模式） | 探针数据收集监听端口（宿主机 host 网络模式） |

### 2. 持久化数据与配置路径

| 宿主机路径 | 容器内挂载路径 | 权限 / 说明 |
| :--- | :--- | :--- |
| `${DATA_PATH}beszel` | `/beszel_data` | `rw`，Beszel Hub 嵌入式 PocketBase 数据库与历史监控指标 |
| `${DATA_PATH}beszel-agent` | `/var/lib/beszel-agent` | `rw`，Beszel Agent 本地状态与缓存数据 |
| `/var/run/docker.sock` | `/var/run/docker.sock` | `ro`，宿主机 Docker 守护进程套接字（用于容器状态监控） |

---

## 🚀 启动与配置流程

Beszel 采用 **中心端 Hub + 探针 Agent** 的两步配置机制：

### 第一步：启动 Beszel Hub

1. 在 `observability/docker-compose.yml` 中取消对 Beszel 的注释：

   ```yaml
   include:
     - beszel/docker-compose.yml # Beszel 轻量服务器监控服务端与 Web 看板
   ```

2. 启动 Hub 容器：

   ```bash
   docker compose up -d beszel
   ```

3. 访问 Web 控制台并创建管理员：
   - 本地访问：`http://localhost:8090`
   - 网关域名访问：`https://beszel.<你的域名>`（需在 Caddy 中启用反代规则）
   - 首次打开将引导你创建首个管理员账号密码。

### 第二步：获取探针凭证并启动 Agent

1. 登录 Beszel Web 界面，点击仪表板右上角的 **「Add System」** 按钮。
2. 在弹出窗口中输入系统名称（例如 `DevOps-Local`），系统会自动生成专用的 **Public Key** 与 **Token**。
3. 复制生成的密钥信息，在 `observability/beszel/docker-compose.yml` 中配置 `beszel-agent` 环境变量（或设置在根目录 `.env` 中）：

   ```yaml
   beszel-agent:
     image: henrygd/beszel-agent:0.21.0
     container_name: beszel-agent
     restart: unless-stopped
     network_mode: host
     volumes:
       - /var/run/docker.sock:/var/run/docker.sock:ro
       - ${DATA_PATH}beszel-agent:/var/lib/beszel-agent
     environment:
       - PORT=45876
       - KEY=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...（替换为你的公钥）
       - TOKEN=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx（替换为你的Token）
       - HUB_URL=http://127.0.0.1:8090
   ```

4. 启动探针：

   ```bash
   docker compose up -d beszel-agent
   ```

5. 回到 Web 界面，刷新页面即可看到当前服务器的秒级动态系统指标与容器统计数据。

---

## 🌐 Caddy 反向代理网关接入

在 `gateways/caddy/Caddyfile` 中取消注释预置的反代规则：

```caddyfile
import proxy-app beszel.{$SITE_ADDRESS} beszel:8090
```

重载 Caddy 网关：

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## 🔍 健康检查与运维排查

```bash
# 检查 Hub 容器健康状态
docker inspect --format='{{json .State.Health}}' beszel

# 查看 Hub 运行日志
docker compose logs -f beszel

# 查看 Agent 运行日志（排查探针连通性与权限）
docker compose logs -f beszel-agent

# 查看 Beszel 容器轻量级资源消耗情况
docker stats beszel beszel-agent --no-stream
```
