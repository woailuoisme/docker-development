# dnsmasq 本地 DNS 配置

dnsmasq 用于本地开发环境的 DNS 解析，支持 `.test` 和 `.local` 域名通配符解析。

## 服务信息

- 端口：`5354`（避免与 macOS mDNS 的 5353 端口冲突）
- 解析规则：
  - `*.test` → `127.0.0.1`
  - `*.local` → `127.0.0.1`

## macOS 配置

### 1. 创建 resolver 目录

```bash
sudo mkdir -p /etc/resolver
```

### 2. 配置 .test 域名解析

```bash
sudo bash -c 'echo "nameserver 127.0.0.1
port 5354" > /etc/resolver/test'
```

### 3. 配置 .local 域名解析（可选）

> 注意：`.local` 域名可能与 macOS Bonjour 服务冲突

```bash
sudo bash -c 'echo "nameserver 127.0.0.1
port 5354" > /etc/resolver/local'
```

### 4. 验证配置

```bash
# 查看 resolver 配置
scutil --dns | grep -A 5 "resolver #"

# 测试解析
dig @127.0.0.1 -p 5354 api.test
ping -c 1 api.test
ping -c 1 example.local
```

## Clash Verge 配置（可选）

如果使用 Clash Verge，可以在配置中添加 DNS 规则，将 `.test` 和 `.local` 域名转发到 dnsmasq：

```yaml
dns:
  nameserver:
    - 127.0.0.1:5354
  nameserver-policy:
    "+.test": "127.0.0.1:5354"
    "+.local": "127.0.0.1:5354"
```

## 常用命令

```bash
# 启动服务
docker-compose up -d dnsmasq

# 重启服务
docker-compose restart dnsmasq

# 查看日志
docker logs dnsmasq -f

# 测试 DNS 解析
dig @127.0.0.1 -p 5354 api.test
dig @127.0.0.1 -p 5354 example.local
```

## 自定义域名

编辑 `dnsmasq.conf` 添加自定义域名解析：

```conf
# 单个域名
address=/myapp.dev/192.168.1.100

# 通配符域名
address=/.dev/127.0.0.1
```
