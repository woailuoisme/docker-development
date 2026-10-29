# Shadowsocks-Rust 客户端 (sslocal-rust)

[shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust) 是官方现代 Rust 版本的 Shadowsocks 客户端实现，提供本地高性能 SOCKS5 代理。

## 部署定位

- 部署位置：本地开发机、内网中继节点或需走代理的容器主机。
- 监听端口：`1080`（TCP 本地 SOCKS5）。
- 配置文件：`gateways/shadowsocks-rust-client/config.json`。

---

## 配置文件说明

```json
{
  "server": "ssserver-rust",
  "server_port": 8388,
  "local_address": "0.0.0.0",
  "local_port": 1080,
  "password": "replace_with_your_strong_password",
  "method": "aes-256-gcm",
  "timeout": 300,
  "fast_open": false,
  "mode": "tcp_and_udp"
}
```

> **注意**：
>
> - 若连接远程 VPS，请将 `"server"` 的值修改为远程服务器的公网 IP 或域名，并保持 `"password"` 与服务端一致。
> - `"local_address"` 必须为 `"0.0.0.0"`，以便 Docker 端口映射能够正确接收宿主机流量。

---

## 常用操作

```bash
# 启动客户端
docker compose --profile client up -d sslocal-rust

# 查看日志
docker compose logs -f sslocal-rust

# 测试代理连通性
curl -x socks5h://127.0.0.1:1080 https://ipinfo.io
```
