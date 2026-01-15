# Kubernetes 配置

本目录包含将 Lunchbox 项目部署到 Kubernetes 的所有配置文件。

## 目录结构

```text
k8s/
├── helm/                           # Helm Charts
│   └── lunchbox/                   # 主应用 Chart
│       ├── Chart.yaml              # Chart 元数据
│       ├── values.yaml             # 默认配置
│       ├── values-dev.yaml         # 开发环境配置
│       ├── values-staging.yaml     # 预发布环境配置
│       ├── values-prod.yaml        # 生产环境配置
│       ├── charts/                 # 依赖 Charts
│       └── templates/              # Kubernetes 资源模板
│           ├── deployments/        # Deployment 资源
│           ├── statefulsets/       # StatefulSet 资源
│           ├── services/           # Service 资源
│           ├── configmaps/         # ConfigMap 资源
│           ├── secrets/            # Secret 资源
│           ├── ingress/            # IngressRoute 资源
│           └── rbac/               # RBAC 资源
├── argocd/                         # ArgoCD GitOps 配置
│   ├── applications/               # Application 资源
│   ├── repo-secrets/               # Git 仓库凭证
│   ├── webhook-examples/           # Webhook 配置示例
│   ├── WEBHOOK.md                  # Webhook 配置指南
│   └── README.md                   # ArgoCD 使用指南
├── scripts/                        # 部署和管理脚本
└── docs/                           # 文档

## 快速开始

### 前置条件

- Kubernetes v1.33.5+
- Helm v4.0.4+
- kubectl 已配置
- ArgoCD v3.2.2+ (可选，用于 GitOps)

### 本地部署

```bash
# 1. 安装 Traefik Ingress Controller
./scripts/install-traefik.sh

# 2. 部署应用到开发环境
./scripts/deploy.sh dev

# 3. 验证部署
./scripts/verify.sh
```

### 使用 ArgoCD 部署（推荐）

ArgoCD 提供 GitOps 工作流，实现自动化部署和配置管理。

```bash
# 1. 安装 ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. 配置 Git 仓库凭证
# 编辑并应用对应的仓库凭证（GitHub/Gitea/Gitee）
kubectl apply -f argocd/repo-secrets/repo-secret-github.yaml

# 3. 创建 Application
kubectl apply -f argocd/applications/application-dev.yaml

# 4. 查看同步状态
argocd app get lunchbox-dev

# 5. 配置 Webhook（可选，实现自动同步）
# 参考 argocd/WEBHOOK.md
```

详细说明请参考 [argocd/README.md](argocd/README.md)

## 环境配置

- **dev**: 开发环境，自动同步，单副本
- **staging**: 预发布环境，自动同步，多副本
- **prod**: 生产环境，手动同步，高可用配置

## 支持的 Git 仓库

- GitHub
- Gitea (自托管)
- Gitee (码云)
- GitLab

## 文档

- [管理指南](docs/MANAGEMENT.md)
- [部署指南](docs/DEPLOYMENT.md)
- [配置指南](docs/CONFIGURATION.md)
- [故障排查](docs/TROUBLESHOOTING.md)
- [安全指南](docs/SECURITY.md)
- [ArgoCD 使用](argocd/README.md)

## 架构

```text
外部请求 → Traefik Ingress → 应用层 (PHP-FPM, RoadRunner, etc.)
                ↓
         ForwardAuth → Authelia (认证)
                ↓
         数据层 (PostgreSQL, Redis, MinIO, etc.)
```

## 技术栈

- **Ingress Controller**: Traefik v3.x
- **认证**: Authelia
- **数据库**: PostgreSQL 16
- **缓存**: Redis 7
- **搜索**: Meilisearch
- **对象存储**: MinIO
- **GitOps**: ArgoCD v3.2.2
