# Stalwart Mail Server (现代化安全全功能邮件服务器)

本项目基于开源的高性能全功能邮件服务器 [Stalwart Mail Server](https://github.com/stalwartlabs/stalwart)（由 Rust 开发），为本开发与生产环境提供轻量、现代、内存安全的企业级私有邮件服务基础设施。

---

## 🌟 核心特性与优势

- **全协议栈一体化 (All-In-One)**：
  - 单一轻量二进制整合所有组件，彻底终结传统 Linux 邮件服务（Postfix + Dovecot + SpamAssassin + OpenDKIM + Rspamd 等）繁琐碎片化的拼装架构。
  - 原生支持 **JMAP** (RFC 8620 / RFC 8621，下一代极速邮件协议)、**IMAP4rev2**、**POP3**、**SMTP** (含 Submission 465 / 587) 以及 **ManageSieve** (RFC 5804)。
- **Rust 内存安全与极速并发**：原生异步 I/O 设计，资源消耗极低，无惧 C/C++ 内存破坏漏洞，高负载下表现极其稳定。
- **现代化内建安全防御**：开箱即用集成 **SPF**、**DKIM**（支持 ED25519 / RSA 多密钥轮换）、**DMARC**、**ARC** 验证与签名，内建速率限制、Sieve 邮件过滤规则与反垃圾引擎。
- **极简嵌入式存储**：自带高性能嵌入式 **RocksDB** 数据库，开箱即用零依赖，重启不丢失用户与邮件状态；亦可按需横向扩展对接外部 PostgreSQL、MySQL、S3/Garage 对象存储或 Redis/Valkey。
- **现代化 Web 管理后台**：内置 Web Admin 控制台，支持可视化管理域名、邮箱账号、邮件别名、用户群组、TLS 证书与全局安全策略。

---

## 🏗️ 协议与端口矩阵

| 协议 / 服务 | 容器端口 | 宿主机端口 | 说明与使用场景 |
| :--- | :--- | :--- | :--- |
| **SMTP** | `25` | `25:25` | 跨邮件服务器间标准邮件传输与入站投递 |
| **SMTPS** | `465` | `465:465` | 客户端隐式 TLS 安全邮件提交 (Implicit TLS) |
| **Submission** | `587` | `587:587` | 客户端显式 STARTTLS 邮件安全提交 |
| **IMAPS** | `993` | `993:993` | 客户端隐式 TLS 安全邮件检索读取 (推荐) |
| **IMAP** | `143` | `143:143` | 客户端显式 STARTTLS 邮件检索读取 |
| **ManageSieve** | `4190` | `4190:4190` | Sieve 邮件服务端过滤规则远程管理协议 |
| **Web Admin / JMAP** | `8080` | `8080:8080` | Web 管理控制台、初始化向导及 JMAP HTTP API |

> [!NOTE]
> 如需使用传统 POP3 协议，可在 `docker-compose.yml` 中取消注释 `110:110` (POP3) 或 `995:995` (POP3S) 端口。

---

## 🚀 快速启动

### 1. 启用模块化编排

在根目录 `docker-compose.yml` 中启用 `apps`：

```yaml
include:
  # ...
  - apps/docker-compose.yml
```

并在 `apps/docker-compose.yml` 中取消注释 `stalwart`：

```yaml
include:
  # ...
  - stalwart/docker-compose.yml
```

### 2. 启动服务

```bash
docker compose up -d stalwart
```

查看实时日志：

```bash
docker compose logs -f stalwart
```

---

## 🔑 初始化引导与管理员登录

Stalwart 容器首次运行且配置目录为空时，将自动进入引导设置模式（Bootstrap Mode）。

### 预设恢复管理员账号

配置中已预置初始管理员认证凭据（可通过根目录 `.env` 按需覆盖）：

```env
STALWART_RECOVERY_ADMIN=admin:stalwart123
```

- **登录地址**：访问 `http://localhost:8080`（或网关反代地址 `https://mail.{$SITE_ADDRESS}`）。
- **默认用户**：`admin`
- **默认密码**：`stalwart123`

> [!TIP]
> 初次登录 Web 控制台完成系统向导并配置正式管理员账户后，建议在 `docker-compose.yml` 中删除或注释掉 `STALWART_RECOVERY_ADMIN` 环境变量以增强安全性。

---

## 💾 持久化与权限规范

数据目录依据项目 `AGENTS.md` 规约持久化至宿主机 `${DATA_PATH}`：

| 挂载源路径 | 容器内目标路径 | 存储内容说明 |
| :--- | :--- | :--- |
| `${DATA_PATH}stalwart/data` | `/var/lib/stalwart` | 邮件数据、用户账户库、DKIM 密钥、RocksDB 数据库 |
| `${DATA_PATH}stalwart/etc` | `/etc/stalwart` | 运行时导出的动态配置、服务器配置备份及证书缓存 |

> [!IMPORTANT]
> Stalwart 容器在内部以非特权用户 **UID 2000** 运行。如果宿主机目录遇到读写权限报错，请执行：
>
> ```bash
> sudo chown -R 2000:2000 ./data/stalwart
> ```

---

## 🌐 网关反向代理接入 (Caddy)

如需通过 Caddy 反向代理将 Web Admin 控制台暴露为安全子域名：

在 `gateways/caddy/Caddyfile` 中取消注释或添加如下规则：

```caddyfile
import proxy-app mail.{$SITE_ADDRESS} stalwart:8080
```

重载 Caddy 网关：

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## 📋 邮件域名核心 DNS 记录参考

如需在公网环境中确保邮件能够正常发送并防止被判定为垃圾邮件，请在权威 DNS 服务商处配置以下记录（以域名 `example.com`、邮件主机 `mail.example.com` 为例）：

### 1. MX 邮件交换记录

| 记录类型 | 主机记录 | 记录值 | 优先级 |
| :--- | :--- | :--- | :--- |
| `MX` | `@` | `mail.example.com.` | 10 |

### 2. A 记录 (邮件主机)

| 记录类型 | 主机记录 | 记录值 | 说明 |
| :--- | :--- | :--- | :--- |
| `A` | `mail` | `<您的服务器公网 IPv4>` | 对应邮件服务器公网 IP |

### 3. SPF 记录 (发送方策略框架)

| 记录类型 | 主机记录 | 记录值 |
| :--- | :--- | :--- |
| `TXT` | `@` | `v=spf1 mx ~all` |

### 4. DKIM 记录 (域名密钥识别邮件)

在 Stalwart Web 后台的「Domains」页面生成 DKIM 签名密钥，获取 Selector（如 `default._domainkey`）并填入 DNS：

| 记录类型 | 主机记录 | 记录值 |
| :--- | :--- | :--- |
| `TXT` | `default._domainkey` | `v=DKIM1; k=rsa; p=<从 Stalwart 后台导出的公钥数据>` |

### 5. DMARC 记录 (基于域的消息认证、报告和一致性)

| 记录类型 | 主机记录 | 记录值 |
| :--- | :--- | :--- |
| `TXT` | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@example.com` |

---

## 📱 客户端配置指南 (Thunderbird / Apple Mail / Outlook)

- **接收邮件服务器 (IMAP)**：
  - 服务器名称：`mail.example.com`
  - 端口：`993`
  - 连接安全：`SSL/TLS`
  - 认证方式：常规密码 / 密码认证
- **发送邮件服务器 (SMTP)**：
  - 服务器名称：`mail.example.com`
  - 端口：`465` (SSL/TLS) 或 `587` (STARTTLS)
  - 连接安全：`SSL/TLS` 或 `STARTTLS`
  - 认证方式：常规密码（勾选“发送服务器需要身份验证”）
