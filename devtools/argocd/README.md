# Argo CD 声明式 GitOps 持续交付与多集群编排平台

[Argo CD](https://github.com/argoproj/argo-cd) 是 CNCF 毕业级开源项目，也是云原生领域事实上的**声明式 GitOps 持续交付 (Continuous Delivery) 控制平台**。它以 Git 仓库为唯一真实可信数据源（Single Source of Truth），自动化对比目标集群运行时状态与 Git 期望状态，并提供强大的偏差检测（Drift Detection）、自动自愈（Self-Healing）与可视化仪表盘。

本项目将 Argo CD 服务组件标准化封装至本地 Docker Compose 环境中，提供与外部 Kubernetes 集群对接或内置 K3s 轻量集群演练的完整能力，并已对接 Caddy 网关反向代理。

---

## 🎯 核心架构与组件划分

Argo CD 的核心架构由以下相互解耦的容器微服务协同工作组成：

```text
```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            1. 开发者与运维交互层                                 │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • Web 浏览器 (访问 https://argocd.{$SITE_ADDRESS} 或 http://localhost:8086)      │
│  • CLI 命令行工具 (`argocd app sync`, `argocd cluster add`)                      │
│  • Git 平台 Webhook (Gitea / GitHub / GitLab 代码提交事件触发即时同步)           │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ HTTPS / gRPC
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                     2. 网关反向代理层 (Gateway & Ingress Layer)                  │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • Caddy 网关 (`gateways/caddy/Caddyfile`):                                      │
│    import proxy-app argocd.{$SITE_ADDRESS} argocd:8080                           │
│  • 统一本地泛域名 SSL 证书卸载与 HTTP/2、WebSocket 通信代理                     │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          3. Argo CD 容器微服务编排栈                             │
├──────────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────┐  gRPC (8081)  ┌───────────────────────────────────┐  │
│  │   server (argocd)      ├──────────────►│         repo (argocd-repo)        │  │
│  │ [核心必需 - Web/API]   │              │     [核心必需 - Manifest 渲染]    │  │
│  └───────────┬────────────┘              └─────────────────┬──────────────────┘  │
│              │                                             │                     │
│              │ 会话/应用缓存                                │ 依赖与清单缓存      │
│              ▼                                             ▼                     │
│  ┌────────────────────────────────────────────────────────────────────────────┐  │
│  │              redis (argocd-redis) [架构必需 - 高吞吐状态缓存]              │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
│              ▲                                                                   │
│              │ 应用状态与集群同步                                                │
│  ┌───────────┴────────────────────────────────────────────────────────────────┐  │
│  │                   controller (argocd-controller)                           │  │
│  │           [核心必需 - Kubernetes CRD 比对、自动同步与自愈控制器]           │  │
│  └───────────────────────────────────┬────────────────────────────────────────┘  │
└──────────────────────────────────────┼───────────────────────────────────────────┘
                                       │
                                       │ Kubeconfig API 通信 (6443)
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          4. Kubernetes 目标集群控制面                            │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 方案 A: 宿主机已有集群 (Docker Desktop K8s / OrbStack / Minikube / 远程集群)   │
│  • 方案 B: 容器内置沙箱 (内置 `k3s` 服务容器，通过 `--profile k3s` 按需启动)      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 镜像源与版本说明

- **官方推荐源**：`quay.io/argoproj/argocd:v3.5.3`。
- **Docker Hub 镜像提示**：Docker Hub 上的 `argoproj/argocd` 上游已停止推流最新标签（历史归档至 v2.6），官方所有生产镜像一律发布在 **Quay.io**。本配置采用经过验证的最新稳定发布版 `v3.5.3`。
- **缓存组件**：`redis:7.4-alpine`，提供高性能轻量内存缓存。
- **可选沙箱集群**：`rancher/k3s:v1.31.5-k3s1`，作为可选内置独立轻量 Kubernetes 控制面。

---

## 🚀 运行模式与快速上手

针对单台服务器或本地开发机资源有限的场景，本项目全面重构为**官方标准的 Argo CD Core 极简低配生产架构**：

- **默认模式（Argo CD Core）**：只启动 `controller` + `repo` + `redis` 核心 GitOps 引擎，裁撤持续运行的 Web UI 与沙箱 K3s，常驻总内存仅需 **< 200MB**。
- **按需唤醒 Web 控制台（Profile: ui）**：仅在需要直观排查应用拓扑时执行 `docker compose --profile ui up -d server`。
- **内置沙箱（Profile: k3s）**：仅在本地宿主无 K8s 时按需启动。

---

### 模式 A：Argo CD Core 极简模式（单机默认推荐，内存开销 < 200MB）

1. **准备宿主机 Kubeconfig**：
   将目标 Kubernetes 集群配置拷贝至本目录（支持 Docker Desktop K8s、OrbStack、Minikube 或云端托管集群）：

   ```bash
   mkdir -p devtools/argocd/kube
   cp ~/.kube/config devtools/argocd/kube/config
   ```

   > **提示**：若使用 Docker Desktop / OrbStack，请确保 `devtools/argocd/kube/config` 中的 server 地址指向 `https://host.docker.internal:6443`。

2. **默认一键拉起 Core 核心 GitOps 引擎**：

   ```bash
   # 仅启动 controller + repo + redis，内存极低
   docker compose up -d
   ```

3. **声明式下发与管理应用**：
   在 Core 模式下无需通过 Web 界面点击，直接使用原生 Kubernetes 清单驱动：

   ```bash
   # 方式 1: 直接使用 kubectl 应用本目录下的 Application CRD
   kubectl apply -f devtools/argocd/apps/application.example.yaml

   # 方式 2: 使用官方 argocd CLI 的 --core 模式管理 (免 Server/免登录)
   argocd --core app list
   argocd --core app get demo-guestbook
   argocd --core app sync demo-guestbook
   ```

---

### 模式 B：临时唤醒 Web UI 控制台 (Profile: ui)

当需要可视化审查资源树或排查同步错误时，通过 Compose Profile 临时唤醒 Web 控制台：

```bash
# 临时拉起 server 容器 (映射 8086:8080)
docker compose --profile ui up -d server

# 排查完毕后随时停用 Web UI 释放资源
docker compose stop server
```

---

### 模式 C：内置 K3s 独立沙箱模式 (Profile: k3s)

如果宿主机**没有任何 Kubernetes 环境**，想在纯 Docker 环境下完整演练：

```bash
docker compose --profile k3s up -d
```

---

## 🌐 访问端点与服务必要性及资源限额分析

| Service 服务名 | Container 容器名 | 必要性等级 | 默认启动 | 内存上限 (Limit) | 运行时内存保护 | 内部通信/宿主端口 |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **`controller`** | `argocd-controller` | **核心必需** (GitOps 状态机与自愈) | ✅ 是 | `384M` | `GOMEMLIMIT=320MiB` | 监听 K8s API |
| **`repo`** | `argocd-repo` | **核心必需** (Git 克隆与 Manifest 渲染) | ✅ 是 | `256M` | `GOMEMLIMIT=200MiB` | `argocd-repo:8081` |
| **`redis`** | `argocd-redis` | **架构必需** (官方缓存组件与会话状态) | ✅ 是 | `64M` | `maxmemory 48mb` | `argocd-redis:6379` |
| **`server`** | `argocd` | **可选扩展** (Web UI 与 API 网关) | ❌ (`--profile ui`) | `256M` | `GOMEMLIMIT=200MiB` | `8086:8080` / `https://argocd.{$SITE_ADDRESS}` |
| **`k3s`** | `argocd-k3s` | **可选扩展** (内置独立 K8s 沙箱) | ❌ (`--profile k3s`) | `1G` | 内核 cgroups | `6443:6443` |

### 各微服务必要性详细说明

1. **`controller` (容器名: `argocd-controller`) - [核心必需]**
   - **职责**：GitOps 状态机核心。持续 Watch Kubernetes 集群中的应用资源，对比 Git 期望状态与实时状态，检测差异并执行自动化同步（Auto-Sync）与自愈。
   - **单机优化**：配置 `mem_limit: 384M` 与 `GOMEMLIMIT=320MiB`，防止集群资源过多时 Go 垃圾回收滞后导致 OOM。

2. **`repo` (容器名: `argocd-repo`) - [核心必需]**
   - **职责**：负责从 Git/Helm 仓库克隆代码，执行 `kustomize build`、`helm template` 等清单生成工具，将应用定义转换为原生 K8s YAML 清单。
   - **单机优化**：配置 `mem_limit: 256M` 与 `GOMEMLIMIT=200MiB`，且临时渲染目录挂载至数据盘。

3. **`redis` (容器名: `argocd-redis`) - [架构必需]**
   - **职责**：官方原生架构强依赖。缓存 Git 仓库清单解析结果与 K8s 实时资源树索引。
   - **单机优化**：配置 `--maxmemory 48mb --maxmemory-policy allkeys-lru`，防止内存无上限膨胀，容器内存硬限额 `64M`。

4. **`server` (容器名: `argocd`) - [可选扩展 (Profile: ui)]**
   - **职责**：提供 Web 仪表盘控制台与 REST/gRPC API。
   - **单机优化**：默认由 `profiles: [ui]` 屏蔽，仅在需要界面操作时按需启动，不常驻占用 200MB+ 内存。

5. **`k3s` (容器名: `argocd-k3s`) - [可选扩展 (Profile: k3s)]**
   - **职责**：在宿主机无 K8s 时提供单节点沙箱。默认关闭，省去 500MB~1GB 内存。

---

### Caddy 网关配置启用 (仅在使用 Web UI 时需要)

编辑 `gateways/caddy/Caddyfile`，取消以下反代规则的注释并重载 Caddy：

```caddyfile
import proxy-app argocd.{$SITE_ADDRESS} argocd:8080
```

随后直接在浏览器访问 `https://argocd.test.local`（以本地站点域名为准）即可安全直连。

---

## 🔑 初始管理员账号与凭据管理 (仅 Web UI 模式)

默认初始管理员用户名为 **`admin`**。

在连接的目标 Kubernetes 集群中，Argo CD 将初始化密码自动存放在 `argocd` 命名空间的 Secret 中：

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
```

---

## 💻 常用运维与管理命令

```bash
# 启动默认 Core 模式 (Controller + Repo + Redis)
docker compose up -d

# 查看核心微服务状态与内存消耗
docker compose ps
docker stats --no-stream argocd-controller argocd-repo argocd-redis

# 唤醒 Web UI 控制台
docker compose --profile ui up -d server

# 关闭 Web UI 控制台以释放内存
docker compose stop server

# 查看 Controller 实时日志
docker compose logs -f controller

# 停止全部服务栈
docker compose down
```

---

## 📂 目录与持久化规范

```text
devtools/argocd/
├── docker-compose.yml       # Argo CD 服务编排定义文件 (Core 极简版)
├── apps/                    # 声明式 GitOps 应用定义目录
│   ├── .gitkeep             # 目录占位符
│   └── application.example.yaml # 样例应用 CRD 声明文件
├── kube/                    # Kubeconfig 挂载目录
│   ├── .gitkeep             # 目录占位符
│   └── config.example       # Kubeconfig 样例配置模板
└── README.md                # 架构设计与运维操作文档
```

持久化数据路径（依照根目录 `.env` 的 `${DATA_PATH}` 规约统一存储）：

- `${DATA_PATH}devtools/argocd/server/`：Argo CD Server 运行时缓存与状态（使用 UI 时）
- `${DATA_PATH}devtools/argocd/repo/`：Git 仓库工作区与临时渲染缓存
- `${DATA_PATH}devtools/argocd/controller/`：应用控制器内部工作状态
- `${DATA_PATH}devtools/argocd/redis/`：Redis 内存数据库快照
- `${DATA_PATH}devtools/argocd/k3s/`：内置 K3s 节点数据卷（当启用 k3s profile 时）
