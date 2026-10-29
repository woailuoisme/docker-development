# Shadowsocks-Rust 服务端 (ssserver-rust)

[shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust) 是官方现代 Rust 版本的 Shadowsocks 服务端实现。

## 部署定位

- 部署位置：公网 VPS 或网关边缘节点。
- 监听端口：`8388`（TCP 与 UDP）。
- 配置文件：`gateways/shadowsocks-rust-server/config.json`。

---

## 配置文件说明

```json
{
  "server": "0.0.0.0",
  "server_port": 8388,
  "password": "replace_with_your_strong_password",
  "method": "aes-256-gcm",
  "timeout": 300,
  "fast_open": false,
  "mode": "tcp_and_udp"
}
```

> **安全建议**：在公网部署时，请务必修改默认 `password` 并配置防火墙放行 `8388/tcp` 与 `8388/udp`。

---

## 常用操作

```bash
# 启动服务端
docker compose up -d ssserver-rust

# 查看日志
docker compose logs -f ssserver-rust

# 重载或重启
docker compose restart ssserver-rust
```

