# Rathole (基于 Rust 的极速安全轻量内网穿透工具)

本项目基于开源的 Rust 高性能内网穿透与反向代理工具 [Rathole](https://github.com/rapiz1/rathole)，为 NAT / 防火墙后面的局域网服务提供极速、安全、低资源开销的公网暴露与安全隧道能力。

---

## 🌟 核心特性与优势

- **极致性能与超低内存**：使用 Rust 编写，无需 Go 运行时的 GC 开销，单连接常驻内存仅数十 KB 到数 MB，CPU 占用极低，吞吐量远超同类工具（如 frp、ngrok）。
- **现代安全模型**：
  - **强制服务隔离认证**：每个穿透服务强制配置独立 Token，防止未授权访问。
  - **Noise 协议端到端加密**：支持基于 Noise Protocol Framework（X25519 + ChaCha20Poly1305）的无证书现代传输层加密，抗中间人攻击（MITM）。
- **统一轻量镜像**：基于 `rapiz1/rathole:v0.5.0`，无多余依赖与臃肿进程。
- **灵活的 Server / Client 编排架构**：单个 Compose 文件集成服务端与客户端定义，并通过 Docker Compose `profiles: [client]` 机制隔离客户端，避免无公网配置时误启动崩溃。
- **配置热重载**：修改配置后支持平滑热加载（SIGHUP），现有活跃连接不受中断。

---

## 🏗️ 架构与服务组织

| 角色 / 容器 | 部署位置 | 默认启动方式 | 核心职责 |
| :--- | :--- | :--- | :--- |
| **`rathole-server`** | 具有公网 IP 的服务器 / 云网关 | 默认随 stack 启动 | 监听控制通道端口 (`2333`)，对外暴露穿透服务的访问端口 (`5200`) 或对接 Caddy 反代 |
| **`rathole-client`** | 位于内网 / NAT 后面的目标机器 | 通过 `--profile client` 按需启动 | 连接公网服务端隧道，将公网流量安全转发到内网本地服务端口 (如 `127.0.0.1:8080`) |

---

## 🔌 端口与持久化规范

### 1. 核心端口

| 协议 / 服务 | 容器端口 | 宿主机映射 | 说明 |
| :--- | :--- | :--- | :--- |
| **控制传输隧道** | `2333/tcp` | `2333:2333/tcp` | 服务端用于与客户端建立加密长连接的控制端口 |
| **穿透业务端口 (示例 Web)** | `5200/tcp` | `5200:5200/tcp` | 服务端对外暴露的被穿透服务端口（亦可通过 Caddy 进行域名反代） |

### 2. 挂载路径

| 宿主机路径 | 容器内挂载路径 | 说明 |
| :--- | :--- | :--- |
| `./server.toml` | `/app/server.toml:ro` | Rathole 服务端配置文件 |
| `./client.toml` | `/app/client.toml:ro` | Rathole 客户端配置文件 |

---

## 🚀 快速启动指南

### 第一步：配置服务端与启动 (Server)

1. 编辑 `gateways/rathole/server.toml`，设置通信密钥与需要穿透的服务：

   ```toml
   [server]
   bind_addr = "0.0.0.0:2333"

   [server.transport]
   type = "tcp"

   [server.services.web]
   token = "your_custom_secret_token_here"
   bind_addr = "0.0.0.0:5200"
   ```

2. 在 `gateways/docker-compose.yml` 中取消对 Rathole 的注释：

   ```yaml
   include:
     - rathole/docker-compose.yml # Rathole 基于 Rust 的极速轻量内网穿透与安全反代
   ```

3. 启动服务端容器：

   ```bash
   docker compose up -d rathole-server
   ```

4. 验证服务端运行状态：

   ```bash
   docker compose logs -f rathole-server
   ```

---

### 第二步：配置并启动内网客户端 (Client)

客户端通常部署在需要被穿透的内网机器上：

1. 编辑 `gateways/rathole/client.toml`：
   - 将 `YOUR_SERVER_PUBLIC_IP` 替换为服务端的公网 IP 或域名。
   - 保持 `token` 与服务端配置完全一致。
   - `local_addr` 填写内网机器实际运行的服务地址（例如本地 Web 服务 `127.0.0.1:8080`）。

   ```toml
   [client]
   remote_addr = "YOUR_SERVER_PUBLIC_IP:2333"

   [client.transport]
   type = "tcp"

   [client.services.web]
   token = "your_custom_secret_token_here"
   local_addr = "127.0.0.1:8080"
   ```

2. 启动客户端容器（启用 `client` profile）：

   ```bash
   docker compose --profile client up -d rathole-client
   ```

3. 查看客户端连接日志：

   ```bash
   docker compose logs -f rathole-client
   ```

---

## 🔐 启用 Noise 协议传输层端到端加密 (可选推荐)

Noise 协议提供轻量级 X25519 密钥交换与 ChaCha20Poly1305 加密，无需配置 SSL 证书：

### 1. 生成密钥对

运行一次性命令生成 X25519 私钥与公钥：

```bash
docker run --rm rapiz1/rathole:v0.5.0 --genkey x25519
```

命令将输出形如：

```text
Private Key: <SERVER_PRIVATE_KEY>
Public Key:  <SERVER_PUBLIC_KEY>
```

### 2. 服务端配置 (`server.toml`)

```toml
[server.transport]
type = "noise"

[server.transport.noise]
pattern = "Noise_NK_25519_ChaChaPoly_BLAKE2s"
local_private_key = "<SERVER_PRIVATE_KEY>"
```

### 3. 客户端配置 (`client.toml`)

```toml
[client.transport]
type = "noise"

[client.transport.noise]
pattern = "Noise_NK_25519_ChaChaPoly_BLAKE2s"
remote_public_key = "<SERVER_PUBLIC_KEY>"
```

---

## 🌐 网关与 Caddy 反向代理集成

Rathole 服务端容器已自动接入统一的 `frontend` 网络，穿透的 Web 服务可直接由 Caddy 提供 HTTPS 自动证书与域名反代：

在 `gateways/caddy/Caddyfile` 中取消对应规则的注释：

```caddyfile
import proxy-app rathole.{$SITE_ADDRESS} rathole-server:5200
```

随后重载网关即可生效：

```bash
docker compose restart caddy
```
