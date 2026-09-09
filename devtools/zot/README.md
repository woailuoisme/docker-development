# Zot OCI 原生高性能容器镜像仓库 (Container Registry)

[Zot](https://github.com/project-zot/zot) 是一款由 Linux 基金会及 CNCF 托管、基于 Go 语言构建的现代化 **OCI 原生高性能容器镜像与制品 (Artifact) 仓库**。完全遵循 [OCI Image Specification v1.1](https://github.com/opencontainers/image-spec) 与 [OCI Distribution Specification v1.1.1](https://github.com/opencontainers/distribution-spec)。

本项目为 Zot 配备了**开箱即用的 Web UI**、**OCI 搜索扩展**、**Prometheus 指标监控**、**Docker 镜像格式兼容 (`docker2s2`)**、**存储去重与自动垃圾回收 (GC)** 以及**细粒度 RBAC 权限控制**，并已接入 Caddy 网关 HTTPS 反向代理。

---

## 🎯 为什么选择 Zot？

在自建私有镜像仓库时，传统方案常常面临体积臃肿、依赖数据库繁琐或功能单一等问题：

| 维度 | **Zot (本项目选型)** | **Harbor** | **Docker Registry (v2/distribution)** |
| :--- | :--- | :--- | :--- |
| **架构与资源消耗** | **单二进制/极简 Distroless**，内存占用极低 (<50MB)，秒级冷启动 | 庞大的微服务集群 (PostgreSQL, Redis, Core, Jobservice 等)，内存需 2GB~4GB+ | 单二进制，但缺乏官方 UI 与制品扩展生态 |
| **OCI v1.1 规范** | **原生全面支持** OCI 引用、OCI Artifacts、Cosign 签名与 SBOM 存取 | 依赖升级适配，底层架构相对厚重 | 仅基础 Docker Schema 规范，OCI 1.1 支持滞后 |
| **用户界面 (Web UI)** | **内置现代化轻量 Web SPA**，支持镜像层探查、制品搜索与漏洞标签展示 | 功能完整但界面与组件极其繁重 | **无内置 UI**，需额外寻找第三方前端接入 |
| **存储效率** | **原生内容寻址硬链接去重 (Dedupe) + 自动 GC**，极致节省本地磁盘 | 需手动触发 GC 任务，且去重机制较重 | 需手动停写后运行 `registry garbage-collect` |
| **生态兼容性** | **内置 `docker2s2` 自动转译**，完美兼顾 Docker CLI 与 Podman/Skopeo | 兼容良好 | 原生 Docker 格式 |
| **扩展能力** | 原生集成 Prometheus Metrics、OCI Search 扩展、RBAC、CVE 扫描对接 | 原生支持 (集成 Trivy) | 需自行搭建 Exporter 侧车 |

---

## 🏛️ 系统集成架构

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            1. 客户端交互层 (Client Layer)                        │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 开发终端: Docker CLI (`docker push/pull`) / Podman / nerdctl                  │
│  • 运维工具: Skopeo (免 Daemon 镜像搬运/探查) / ORAS (OCI 制品与 Helm Chart 推拉)│
│  • CI/CD 流水线: Woodpecker CI / Gitea Actions / Jenkins 自动构建推流            │
│  • 开发者浏览器: 访问 Web UI 检索镜像、探查镜像层元数据                         │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ HTTPS / HTTP API 调用
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                     2. 网关反向代理层 (Gateway & Ingress Layer)                  │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • Caddy 网关 (`gateways/caddy/Caddyfile`):                                      │
│    import proxy-app registry.{$SITE_ADDRESS} zot:5000                            │
│  • 自动加载 mkcert 本地受信通配符证书 (*.{$SITE_ADDRESS})，提供原生 TLS 卸载     │
│  • 保持 HTTP/2 / 流式 Blob 分块上传通道无阻碍                                    │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 127.0.0.1:5000 (宿主保护) / zot:5000 (内部网络)
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          3. Zot 核心服务引擎 (Zot Core)                          │
│                           (ghcr.io/project-zot/zot:latest)                       │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • OCI Distribution Spec v1.1.1 协议引擎 (Manifest / Blob / Tag 服务)            │
│  • 兼容层: compat: ["docker2s2"] (自动适配 Docker 客户端 Manifest V2 Schema 2)   │
│  • 访问控制: htpasswd 认证 + RBAC (Admin 读写删 / 匿名全域只读)                 │
│  • 内置扩展: Web UI (SPA) + OCI Search 索引引擎 + Prometheus /metrics           │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 本地持久化挂载
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          4. 持久化存储层 (Storage Layer)                         │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 配置文件: ./zot-config.json -> /etc/zot/config.json:ro                        │
│  • 密码凭证: ./htpasswd -> /etc/zot/htpasswd:ro (Bcrypt 散列存储)                │
│  • 镜像制品: ${DATA_PATH}zot/registry -> /var/lib/registry                       │
│    (支持原生 SHA256 内容寻址硬链接去重与定期孤立层垃圾回收)                      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔌 端口与服务网络

| 端点 / 端口 | 协议 / 传输层 | 访问作用域 | 说明 |
| :--- | :--- | :--- | :--- |
| `https://registry.{$SITE_ADDRESS}` | HTTPS (443) | 外部/局域网 | Caddy 反向代理网关统一入口，包含 Web UI 与 OCI Registry API |
| `127.0.0.1:5000` | HTTP (TCP) | 宿主机本地 | 绑定本地回环端口，杜绝未授权公网暴露 |
| `zot:5000` | HTTP (TCP) | 内部网络 (`frontend`, `backend`) | 供网关、CI/CD 容器及微服务直接内部高速通信 |

---

## 🔐 认证机制与权限控制 (RBAC)

本项目采用 `htpasswd`（Bcrypt 算法）配合 Zot 原生 `accessControl` 策略，实现兼顾安全性与开发便利性的**“管理员全权 + 匿名用户只读”**模型：

### 1. 默认账号与权限模型

- **管理员账号**：`admin` / `admin`
  - 拥有 `read` (拉取)、`create` (首次推送)、`update` (覆盖推送) 与 `delete` (删除镜像标签及清单) 完整权限。
- **匿名用户 (Anonymous)**：
  - 对所有命名空间与仓库 (`**`) 拥有 `read` 权限（可免密拉取镜像与浏览 Web UI）。
  - 对 `/metrics` 指标端点拥有 `read` 权限（便于监控采集系统无缝抓取）。
- **客户端行为差异**：
  - **Docker CLI**：由于 Docker 客户端遇到 401 质询时会严格中断请求，建议在推送镜像前统一执行 `docker login`。
  - **Podman / Skopeo / ORAS / containerd**：原生深度支持 OCI 规范，拉取公共镜像时无需登录即可直接匿名拉取。

### 2. 管理与新增用户凭证

凭证文件位于 `./htpasswd`。若需修改管理员密码或新增团队成员，可通过以下方式生成 Bcrypt 格式的密文：

#### 方式 A：使用 Apache 命令行工具 (推荐)

```bash
# 修改已存在的 admin 密码
htpasswd -B -b htpasswd admin <new_password>

# 新增一个开发者账号 dev
htpasswd -B -b htpasswd dev <dev_password>
```

#### 方式 B：免安装工具 (通过临时容器生成)

```bash
# 生成 username:password 格式并追加到 htpasswd
docker run --rm httpd:alpine htpasswd -nbB <username> <password> >> htpasswd
```

修改 `./htpasswd` 后，热加载生效：

```bash
docker compose restart zot
```

---

## 🐳 客户端使用指引

在开始使用前，请确保本地已通过 `just trust-mkcert` 信任开发环境根证书，使得 Docker CLI 可以正常信任 `https://registry.{$SITE_ADDRESS}`。

### 1. Docker CLI

#### 登录仓库

```bash
docker login registry.${SITE_ADDRESS}
# 输入用户名: admin
# 输入密码: admin
```

> [!NOTE]
> 如果通过宿主机纯 HTTP 端口 `127.0.0.1:5000` 访问，Docker 可能会提示不受信任的 HTTP 仓库。在生产或标准开发中，始终推荐使用通过 Caddy 反代的受信任域名 `registry.${SITE_ADDRESS}`。

#### 构建、打标与推送镜像

```bash
# 本地构建或拉取公共测试镜像
docker pull alpine:latest

# 打上本地私有仓库标签
docker tag alpine:latest registry.${SITE_ADDRESS}/library/alpine:latest

# 推送到私有仓库
docker push registry.${SITE_ADDRESS}/library/alpine:latest
```

#### 拉取镜像

```bash
docker pull registry.${SITE_ADDRESS}/library/alpine:latest
```

---

### 2. Podman

Podman 原生支持免 Docker Daemon 交互，并无缝支持 OCI 1.1：

```bash
# 登录仓库
podman login registry.${SITE_ADDRESS} -u admin -p admin

# 推送镜像
podman push alpine:latest registry.${SITE_ADDRESS}/my-app/alpine:latest

# 匿名拉取镜像 (无需登录)
podman pull registry.${SITE_ADDRESS}/my-app/alpine:latest
```

---

### 3. Skopeo (免守护进程镜像搬运与探查)

Skopeo 是运维与 CI/CD 中极为高效的工具，能够在无需启动 Docker/Podman 的情况下直接检查、同步远程镜像：

```bash
# 探查私有仓库中的镜像元数据与 Manifest
skopeo inspect --creds admin:admin docker://registry.${SITE_ADDRESS}/library/alpine:latest

# 直接从 Docker Hub 搬运镜像到本地 Zot 私有仓库
skopeo copy \
  --dest-creds admin:admin \
  docker://docker.io/library/redis:alpine \
  docker://registry.${SITE_ADDRESS}/cache/redis:alpine
```

---

### 4. ORAS (OCI 制品与任意文件分发)

Zot 原生支持把 WebAssembly 模块、Helm Chart、配置文件等任意文件作为 OCI Artifacts 推送：

```bash
# 将任意配置文件推送到 Zot
echo "system_config: v1" > config.yaml
oras push registry.${SITE_ADDRESS}/configs/app-config:v1.0.0 \
  --username admin --password admin \
  ./config.yaml:text/plain

# 从 Zot 下载制品文件
oras pull registry.${SITE_ADDRESS}/configs/app-config:v1.0.0 \
  --username admin --password admin
```

---

## 📊 Prometheus 监控集成

Zot 原生暴露标准 Prometheus 指标。指标端点已开放匿名读取：

- **抓取地址**：`http://zot:5000/metrics`（容器内网）或 `https://registry.{$SITE_ADDRESS}/metrics`
- **指标类型**：包含 HTTP 请求耗时、分块上传速率、并发连接数、存储利用率以及 GC 垃圾回收统计。

### Prometheus / VictoriaMetrics 抓取配置示例

在监控采集器配置（如 `vmagent.yml` 或 `prometheus.yml`）中添加：

```yaml
scrape_configs:
  - job_name: "zot-registry"
    metrics_path: "/metrics"
    static_configs:
      - targets: ["zot:5000"]
        labels:
          environment: "development"
          service: "container-registry"
```

---

## 🧹 存储治理与垃圾回收 (GC & Deduplication)

在 `zot-config.json` 中，本项目启用了两项关键存储优化特性：

```json
"storage": {
  "rootDirectory": "/var/lib/registry",
  "gc": true,
  "dedupe": true
}
```

1. **内容寻址去重 (`dedupe: true`)**：
   - 当多个不同镜像或标签共享相同的只读层（Layer Blob）时，Zot 底层利用硬链接（Hard Link）实现跨仓库物理存储去重，极大节约磁盘。
2. **自动垃圾回收 (`gc: true`)**：
   - 自动识别并回收没有 Manifest 引用的孤立 Layer Blobs 与悬空制品，无需运维人员手动停止服务执行离线清理。

---

## 🛠️ 运维与调试常用命令

```bash
# 启动 Zot 服务
docker compose up -d zot

# 检查服务运行状态与日志
docker compose logs -f zot

# 重启服务 (在修改配置或 htpasswd 后)
docker compose restart zot

# 校验 zot-config.json 语法正确性 (使用 zot 内置 verify 命令)
docker run --rm -v $(pwd)/devtools/zot/zot-config.json:/etc/zot/config.json:ro ghcr.io/project-zot/zot:latest zot verify /etc/zot/config.json

# 测试服务就绪探针 (HTTP 200)
curl -I http://127.0.0.1:5000/v2/
```
