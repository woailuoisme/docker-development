# Bore - 极简现代化 Rust TCP 内网穿透服务

[bore](https://github.com/ekzhang/bore) 是一个由 Rust 编写的高性能、轻量级现代 TCP 内网穿透工具。其核心目标与 ngrok 类似，旨在以极小的资源开销在公网服务器上建立反向隧道，将内网本地端口安全暴露至公网。

## 核心特性

- **极致轻量**：单静态二进制，基于 Rust 与 Tokio 异步 I/O 构建，常驻内存仅数 MB。
- **无需复杂配置**：无需编写复杂的服务端配置文件，开箱即用。
- **安全鉴权**：支持基于 HMAC 的客户端连接鉴权（`BORE_SECRET`），防止未授权中继。
- **高效端口转发**：支持指定映射端口或自动分配动态端口。

---

## 端口与网络说明

| 端口/范围 | 协议 | 用途说明 |
| :--- | :--- | :--- |
| `7835` | TCP | Bore 控制信令端口（客户端连接鉴权与信令交换） |
| `10000-10020` | TCP | 预留的公共穿透数据端口段（可在 `command` 中自定义） |

> **网络模式切换说明**：
>
> 1. **默认桥接模式（Bridge）**：适合受限端口环境或与 Docker 内部服务互联，显式映射控制端口 `7835` 与预留数据端口段 `10000-10020`。
> 2. **主机网络模式（Host）**：若在公网独立 VPS 上部署，希望支持任意动态端口范围（`1024-65535`），可将 `ports` 与 `networks` 注释，开启 `network_mode: host`。

---

## 快速使用

### 1. 启动服务端

在公网服务器上启动 `bore-server`：

```bash
docker compose up -d bore-server
```

如需开启身份鉴权，请在根目录 `.env` 文件中设置密钥：

```env
BORE_SECRET=your_strong_secret_token
```

### 2. 客户端连接使用

#### 使用预编译 CLI 二进制（推荐）

从 [bore GitHub Releases](https://github.com/ekzhang/bore/releases) 下载对应平台的二进制并运行：

```bash
# 暴露本地 8080 端口到远程服务器，并指定远程端口 10001
bore local 8080 --to <YOUR_SERVER_IP> --port 10001 --secret your_strong_secret_token

# 自动分配可用端口
bore local 3000 --to <YOUR_SERVER_IP> --secret your_strong_secret_token
```

#### 使用 Docker 运行客户端

```bash
docker run -it --rm ekzhang/bore:0.6 \
  local 8080 --to <YOUR_SERVER_IP> --port 10001 --secret your_strong_secret_token
```
