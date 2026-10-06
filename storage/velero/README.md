# Velero 云原生集群与卷快照容灾备份平台

[Velero](https://github.com/velero-io/velero) (原 Heptio Ark) 是云原生领域事实标准的 Kubernetes 集群备份、迁移与灾难恢复（Disaster Recovery）工具，支持对集群元数据配置（CRD、Deployment、ConfigMap、Secret 等）和持久化存储卷（Persistent Volumes）进行增量备份与快照。

本项目将 Velero 核心控制器、S3 存储插件以及 Web 可视化控制台封装至 Docker Compose 基础设施中，支持无缝对接外部或宿主机 Kubernetes 集群，并将备份数据持久化写入本地 S3 对象存储（如 `storage/garage` 或 MinIO）。

---

## 🎯 核心架构与服务组件

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        1. 开发者与运维交互层                           │
├────────────────────────────────────────────────────────────────────────┤
│  • Web 控制台: http://localhost:8087 或 https://velero.{$SITE_ADDRESS} │
│  • 原生 CLI 指令: docker compose --profile cli run --rm velero-cli ... │
│  • Prometheus 监控: http://localhost:18085/metrics                    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     2. 网关反向代理层 (Caddy)                          │
├────────────────────────────────────────────────────────────────────────┤
│  • Caddyfile: import proxy-app velero.{$SITE_ADDRESS} velero-ui:3000   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     3. Velero 容器编排微服务栈                         │
├────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────┐           ┌──────────────────────────────┐  │
│  │   velero-plugin-aws   ├──────────►│      velero (控制器核心)      │  │
│  │  [S3/AWS 存储插件注入] │ (共享卷)   │  [备份恢复调度 / 8085 监控]   │  │
│  └───────────────────────┘           └──────────────┬───────────────┘  │
│                                                     │                  │
│  ┌───────────────────────────────────────────────┐  │                  │
│  │            velero-ui (Web 控制台)              │  │                  │
│  │   [otwld 开源看板 / 8087:3000 / 前端可视化]     │  │                  │
│  └───────────────────────────────────────────────┘  │                  │
└──────────────────────────────────────┬──────────────┼──────────────────┘
                                       │              │
                   Kubeconfig (API 交互)│              │ S3 API 备份上传 (3900)
                                       ▼              ▼
┌──────────────────────────────────────────┐    ┌────────────────────────┐
│        4. Kubernetes 目标集群            │    │ 5. S3 存储 (Garage)     │
├──────────────────────────────────────────┤    ├────────────────────────┤
│ Docker Desktop K8s / OrbStack / 外部集群 │    │ storage/garage:3900    │
└──────────────────────────────────────────┘    └────────────────────────┘
```

---

## 📦 镜像版本实测与说明

根据项目规范（`AGENTS.md`：禁止写不存在的标签，新增前必须到 Docker Hub / GHCR 实测确认），各组件镜像版本声明如下：

| 组件名称 | 容器名称 | 镜像地址与标签 | 说明 |
| :--- | :--- | :--- | :--- |
| **Velero 控制器** | `velero` | `velero/velero:v1.18.4` | 官方最新稳定版（实测存在）；如需历史 v1.8 系列请使用 `v1.8.1`（官方未发布 `v1.8.4` 标签） |
| **S3 存储插件** | `velero-plugin-aws` | `velero/velero-plugin-for-aws:v1.14.4` | AWS S3 / MinIO / Garage 兼容存储插件 |
| **可视化控制台** | `velero-ui` | `otwld/velero-ui:0.10.3` | 由 otwld 维护的 Velero Web UI 看板 |
| **命令行工具** | `velero-cli` | `velero/velero:v1.18.4` | 免安装宿主机二进制的 CLI 容器工具 |

---

## 🚀 快速上手与配置流程

### 1. 准备 Kubernetes 集群访问凭据 (Kubeconfig)

将宿主机或外部集群的 `kubeconfig` 文件放置到 `storage/velero/kube/` 目录下（参考 `config.example` 模板）：

```bash
mkdir -p storage/velero/kube
cp ~/.kube/config storage/velero/kube/config
```

> **注意**：如果在 macOS 上使用 OrbStack 或 Docker Desktop，请确保 `storage/velero/kube/config` 中的 API Server 地址为主机可解析地址（例如 `https://host.docker.internal:6443`），避免容器内请求 `127.0.0.1` 失败。

### 2. 配置 S3 存储认证凭据 (Credentials)

复制凭据模板并填入对应 S3 访问凭据（若接入项目内部的 `storage/garage`，填入 Garage 分配的 Key 即可）：

```bash
cp storage/velero/credentials/credentials-velero.example storage/velero/credentials/credentials-velero
```

凭据格式（标准 AWS INI 格式）：

```ini
[default]
aws_access_key_id = <YOUR_ACCESS_KEY>
aws_secret_access_key = <YOUR_SECRET_KEY>
```

### 3. 配置 BackupStorageLocation (BSL)

在目标 Kubernetes 集群中应用 BackupStorageLocation 清单（参考 `storage/velero/configs/bsl-garage.example.yaml`）：

```bash
kubectl apply -f storage/velero/configs/bsl-garage.example.yaml
```

### 4. 启动 Velero 服务栈

在根目录或者 `storage/` 模块下执行：

```bash
# 启动 Velero 核心控制器与 Web 控制台
docker compose up -d velero velero-ui
```

---

## 💻 常用运维与命令行操作

通过内置的 `velero-cli` 容器服务，无需在宿主机额外安装 `velero` 二进制文件即可直接执行管理命令：

```bash
# 查看所有备份任务
docker compose --profile cli run --rm velero-cli backup get

# 创建一个即时备份 (示例: 备份 default 命名空间)
docker compose --profile cli run --rm velero-cli backup create default-backup --include-namespaces default

# 查看备份详情与状态
docker compose --profile cli run --rm velero-cli backup describe default-backup

# 查看备份存储位置状态
docker compose --profile cli run --rm velero-cli backup-location get

# 从备份中恢复资源
docker compose --profile cli run --rm velero-cli restore create --from-backup default-backup

# 查看定时调度计划
docker compose --profile cli run --rm velero-cli schedule get
```

---

## 🌐 访问端点

- **Web 控制台 (Velero UI)**: `http://localhost:8087`（或反向代理域名 `https://velero.{$SITE_ADDRESS}`，默认登录用户密码依配置设置）
- **Prometheus 监控指标端点**: `http://localhost:18085/metrics`

---

## 📂 目录结构与持久化规约

```text
storage/velero/
├── docker-compose.yml       # Velero 服务编排定义文件
├── README.md                # 架构设计与运维操作文档
├── kube/                    # Kubeconfig 挂载目录
│   ├── .gitkeep             # 占位符
│   └── config.example       # Kubeconfig 样例模板
├── credentials/             # S3 鉴权凭据挂载目录
│   ├── .gitkeep             # 占位符
│   └── credentials-velero.example # S3 访问凭据样例
└── configs/                 # Kubernetes 资源清单模板
    └── bsl-garage.example.yaml # Garage S3 存储位置与快照位置模板
```

持久化路径遵循项目规约：

- `${DATA_PATH}velero/plugins/`：Velero 存储插件二进制缓存目录
- `${DATA_PATH}velero/scratch/`：临时文件解压与处理缓存目录
