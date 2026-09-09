# goacme/lego - 现代化 Go 原生 ACME 自动化证书管理服务

基于官方 [goacme/lego](https://github.com/go-acme/lego) 构建的高性能、云原生 ACME 泛域名证书自动化管理容器，遵循 **Lego v5** 现代化设计哲学。

---

## 🌟 核心特性与架构对比

| 特性 | gateways/acme (`acme.sh`) | gateways/lego (`goacme/lego v5`) |
| :--- | :--- | :--- |
| **底层核心** | POSIX Shell 脚本 | Go 原生静态编译二进制 |
| **生命周期** | 手动分支区分 issue 与 renew | **Lego v5 统一 `run` 引擎**（未签发则申请，已有效则检查，临期自动续订） |
| **部署机制** | 脚本内多阶段 hook 混杂 | **原生事件驱动 `--deploy-hook`**（仅在证书实际变更时触发同步与重载） |
| **执行性能** | 依赖外部 curl/openssl 多进程调用 | 单进程高并发异步 I/O，毫秒级响应，超低内存开销 |
| **DNS-01 驱动** | 社区 Shell 插件 | 官方维护 100+ 云厂商原生 Go SDK 实现 |
| **凭证管理** | 环境变量或写入配置文件 | 自动脱敏、统一映射转换，同时兼容 Lego 原生环境变量 |
| **输出格式** | 专有 `_ecc` 目录 | 原生 `.lego` + 自动同步标准 `/ssl/live/${DOMAIN}` |
| **下游重载** | Docker Socket HUP | Docker Socket HUP，支持自定义重载目标容器 |
| **测试环境** | 手动配置 Server URL | `LEGO_CA_STAGING=true` 一键防止 Let's Encrypt 限流 |

---

## 🏗️ Lego v5 架构设计哲学

本项目完全摒弃了传统 ACME 包装脚本中的常见反模式（如手动文件存在性判断、`stat` 时间戳轮询比对等），严格采用 Lego v5 推荐规范：

1. **单生命周期原则 (Unified Single Lifecycle)**：
   - 传统设计常在首次启动时执行 `run`，后续循环调用 `renew`。
   - Lego v5 推荐全周期统一调用 `lego run`。若本地已有证书且剩余有效期充足（> 30 天），Lego 将在本地毫秒级验证后安全返回退出码 0，不产生任何网络滥用或重复签发。
2. **纯原生事件驱动部署 (`--deploy-hook`)**：
   - 使用统一的 `--deploy-hook` 取代已废弃的旧版 hook 参数。
   - Lego 仅在证书被成功新颁发或实际续期落地后，才会注入环境变量（`$LEGO_CERT_PATH`, `$LEGO_CERT_KEY_PATH` 等）并调用部署钩子。
   - 脚本采用自递归模式（Self-Invoking: `entrypoint.sh --deploy-hook`），将守护逻辑与部署动作清晰解耦。

---

## 🚀 快速启用

### 1. 启用 Compose 编排

在 `gateways/docker-compose.yml` 中取消注释：

```yaml
include:
  - lego/docker-compose.yml # goacme/lego 现代化 Go 原生 ACME 自动证书管理
```

### 2. 配置环境变量 (`.env`)

```env
# 基础域名与通知邮箱
DOMAIN=example.com
LEGO_EMAIL=admin@example.com

# DNS 提供商 (cloudflare / alidns / tencentcloud 等)
LEGO_DNS_PROVIDER=cloudflare

# Cloudflare DNS API 凭据
CF_API_TOKEN=your_cloudflare_dns_api_token

# 阿里云 DNS API 凭据 (若使用 alidns)
# ALI_ACCESS_KEY=your_aliyun_access_key_id
# ALI_ACCESS_KEY_SECRET=your_aliyun_access_key_secret

# 证书热重载目标容器名称 (默认 nginx，若使用 caddy 可指定 caddy，不重载设为 none)
LEGO_RELOAD_CONTAINER=nginx

# 初次调试建议开启测试环境避免触发 Let's Encrypt 频控限流 (成功后再设为 false)
LEGO_CA_STAGING=false
```

### 3. 启动服务

```bash
docker compose up -d lego
```

查看实时运行日志：

```bash
docker compose logs -f lego
```

---

## 📂 证书文件存储规范

容器运行后，证书将自动持久化并生成两层结构：

1. **Lego 原生数据目录**：挂载于 `${DATA_PATH}lego` (`/.lego`)
   - `certificates/${DOMAIN}.crt`（包含完整证书链 Fullchain）
   - `certificates/${DOMAIN}.key`（私钥）
   - `certificates/${DOMAIN}.issuer.crt`（CA 证书）
   - `certificates/${DOMAIN}.json`（元数据）
2. **标准 Web 网关目录**：挂载于 `${DATA_PATH}ssl` (`/ssl/live/${DOMAIN}`)
   - `fullchain.pem`：完整证书链，供 Nginx / Caddy / Envoy 直接引用
   - `privkey.pem`：私钥（权限自动设为 600）
   - `chain.pem`：CA 证书

Nginx 或 Caddy 引用示例：

```nginx
ssl_certificate /etc/nginx/ssl/live/example.com/fullchain.pem;
ssl_certificate_key /etc/nginx/ssl/live/example.com/privkey.pem;
```

---

## 🔄 自动化续期与服务热重载

1. **自动常驻守护**：容器根据 `LEGO_RENEW_INTERVAL`（默认 12 小时 = 43200 秒）周期性执行 `lego run`。
2. **免重启无感更新**：当证书剩余有效期不足 30 天时，Lego 自动完成 ACME 续订，并触发 `--deploy-hook`。
3. **Docker Socket 信号触发**：部署钩子自动更新 `/ssl/live/${DOMAIN}` 标准证书，并通过 `/var/run/docker.sock` 向 `RELOAD_CONTAINER`（如 `nginx`）发送 `HUP` 信号完成平滑热重载。
