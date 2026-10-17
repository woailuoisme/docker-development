# Headscale (开源轻量级 Tailscale 控制服务器)

本项目基于开源的自建控制端项目 [Headscale](https://github.com/juanfont/headscale)（基于 Go 构建），为虚拟私有局域网（VPN / Mesh Network）提供完全私有化、自主可控的 Tailscale 协调服务器与节点管理中心。

---

## 🌟 核心特性与优势

- **私有可控的 Tailscale 控制面**：替代 Tailscale 官方闭源 SaaS 控制服务，网络节点拓扑、认证密钥与私有通信元数据全部自托管。
- **高性能 WireGuard 组网**：控制端仅负责节点发现与密钥协商，实际流量通过 WireGuard 在节点间加密直连（P2P），不经过控制服务器，速度极高且延迟极低。
- **跨平台客户端原生兼容**：支持 Linux、macOS、Windows、Android、iOS 等官方 Tailscale 客户端直接修改 `--login-server` 接入。
- **MagicDNS 智能域名解析**：内置 MagicDNS 支持，网络内各节点分配固定虚拟 IP（如 `100.64.0.x`）并通过主机名（如 `<node-name>.example.net`）无感互访。
- **子网路由与出口节点 (Exit Node)**：支持通过节点向私网广播局域网网段（Subnet Router），或将某台节点配置为全局出口网关（Exit Node）。
- **内置与公共 DERP 中继支持**：对于对称型 NAT 等无法 P2P 打洞的极端网络环境，支持接入全球公共 DERP 中继或启用本地嵌入式 DERP 服务。

---

## 🏗️ 端口与持久化规范

### 1. 服务端口

| 协议 / 服务 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **HTTP / 控制端 API** | `8080` | `9085:8080` | Tailscale 客户端注册、节点协商与 Web API 端口 |
| **Prometheus 指标** | `9090` | `9095:9090` | 内部健康状态与 Prometheus 监控指标端点 |
| **STUN 协议 (UDP)** | `3478/udp` | `3478:3478/udp` | NAT 穿透辅助探测端口（内置 DERP 服务启用时使用） |

### 2. 持久化数据与配置路径

| 宿主机路径 | 容器内挂载路径 | 权限 / 说明 |
| :--- | :--- | :--- |
| `./config/config.yaml` | `/etc/headscale/config.yaml` | `ro`，Headscale 核心配置文件 |
| `${DATA_PATH}headscale` | `/var/lib/headscale` | `rw`，SQLite 数据库 (`db.sqlite`)、Noise 加密私钥与运行时状态 |
| `tmpfs` (内存挂载) | `/var/run/headscale` | `rw`，CLI Unix Socket (`headscale.sock`) 运行时套接字 |

---

## 🚀 启动与配置流程

### 第一步：检查并调整配置文件

检查 `gateways/headscale/config/config.yaml`：

- `server_url`：客户端连接的外部地址。如果通过 Caddy 等反向代理访问，默认会在 `docker-compose.yml` 中由 `HEADSCALE_SERVER_URL=https://headscale.${SITE_ADDRESS}` 环境变量自动覆盖。
- `base_domain`：MagicDNS 域名（如 `example.net`），注意不能与 `server_url` 的域名相同。

### 第二步：注册并启动服务

1. 在 `gateways/docker-compose.yml` 中取消 Headscale 的注释：

   ```yaml
   include:
     - headscale/docker-compose.yml # Headscale 开源轻量级 Tailscale 控制服务器
   ```

2. 启动 Headscale 容器：

   ```bash
   docker compose up -d headscale
   ```

3. 检查容器运行状态与健康检查：

   ```bash
   docker compose ps headscale
   docker compose logs headscale
   ```

---

## 💻 客户端接入与用户管理指南

### 1. 创建用户 (User)

所有节点都必须绑定到特定用户下。执行以下命令创建用户（例如名为 `admin`）：

```bash
docker exec -it headscale headscale users create admin
```

### 2. 方式 A：通过 Pre-Auth Key 快速免密接入（推荐服务器 / 无头设备）

对于 Linux 服务器、群晖 NAS 或无桌面环境的容器，推荐生成预授权密钥：

```bash
# 生成有效期为 24 小时、可多次使用的 Auth Key
docker exec -it headscale headscale preauthkeys create --user admin --reusable --expiration 24h
```

在客户端机器上安装 Tailscale 后，执行以下命令即可直接上线：

```bash
tailscale up --login-server https://headscale.<你的域名> --authkey <上一步生成的密钥>
```

### 3. 方式 B：通过交互式 URL 认证接入（桌面端与移动端）

在客户端上运行登录命令：

```bash
tailscale up --login-server https://headscale.<你的域名>
```

客户端终端或图形界面将提示一个认证链接（形如 `https://headscale.<你的域名>/register/mkey:...`）：

1. 打开该链接，网页会显示一条注册命令，例如：

   ```bash
   headscale nodes register --user <USER> --key <NODE_KEY>
   ```

2. 在服务端容器中执行该命令完成批准：

   ```bash
   docker exec -it headscale headscale nodes register --user admin --key <NODE_KEY>
   ```

---

## 🛠️ 常用管理命令速查

| 操作场景 | 命令示例 |
| :--- | :--- |
| **查看所有用户** | `docker exec -it headscale headscale users list` |
| **创建新用户** | `docker exec -it headscale headscale users create <username>` |
| **查看所有节点** | `docker exec -it headscale headscale nodes list` |
| **查看节点路由** | `docker exec -it headscale headscale routes list` |
| **启用节点子网路由** | `docker exec -it headscale headscale routes enable -r <route-id>` |
| **重命名节点** | `docker exec -it headscale headscale nodes rename <node-id> <new-name>` |
| **删除离线节点** | `docker exec -it headscale headscale nodes delete -i <node-id>` |
| **创建预认证密钥** | `docker exec -it headscale headscale preauthkeys create --user <user> --reusable` |
| **查看有效密钥** | `docker exec -it headscale headscale preauthkeys list --user <user>` |

---

## 🌐 网关与反向代理集成 (Caddy)

由于 Tailscale 客户端默认要求 HTTPS 安全连接，强烈建议通过网关反向代理：

在 `gateways/caddy/Caddyfile` 中取消注释对应的代理配置规则：

```caddyfile
import proxy-app headscale.{$SITE_ADDRESS} headscale:8080
```

重载 Caddy 即可生效：

```bash
docker compose restart caddy
```
