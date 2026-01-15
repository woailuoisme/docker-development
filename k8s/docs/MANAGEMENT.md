# 项目管理指南 (Management Guide)

根据目前的 Kubernetes 配置，该项目的管理主要围绕 **Helm** (配置管理) 和 **ArgoCD** (交付管理) 两个核心展开。

## 1. 环境管理 (Environment Management)

项目采用了多环境配置模式，通过不同的 Helm values 文件来区分环境：

* **开发环境 (dev)**: 使用 `k8s/helm/lunchbox/values-dev.yaml`。
* **预发布环境 (staging)**: 使用 `k8s/helm/lunchbox/values-staging.yaml`。
* **生产环境 (prod)**: 使用 `k8s/helm/lunchbox/values-prod.yaml`。

**管理动作**：修改对应环境的 `.yaml` 文件来调整副本数、域名、资源限制等。

## 2. 部署管理 (Deployment)

您可以选择两种方式管理部署：

### 方式 A：脚本自动化 (推荐快速操作)

使用项目自带的 `k8s/scripts/` 目录下的脚本：

* **安装入口网关**：`./scripts/install-traefik.sh` (首次部署前执行)。
* **部署应用**：`./scripts/deploy.sh -e dev` (可指定环境)。
* **状态验证**：`./scripts/verify.sh` (检查所有 Pod 和服务是否正常)。
* **资源清理**：`./scripts/cleanup.sh` (销毁环境)。

### 方式 B：GitOps 管理 (生产推荐)

利用 `k8s/argocd/` 中的配置实现同步：

1. 将 `k8s/argocd/applications/` 对应的资源应用到集群。
2. ArgoCD 会自动监控 Git 仓库的变化。
3. **管理动作**：只要您把代码推送到对应的 Git 分支（如 `main`），ArgoCD 会自动更新 Kubernetes 集群中的资源。

## 3. 配置管理 (Configurations & Secrets)

* **普通配置**：集中在 `k8s/helm/lunchbox/values.yaml`。
* **敏感信息**：通过 `k8s/helm/lunchbox/templates/secrets/` 下的模板管理。
* **注意**：在生产环境中，建议配合外部 Secret 管理器（如 SealedSecrets 或 HashiCorp Vault），或手动通过 `kubectl edit secret` 修改默认值。

## 4. 服务观测与日常运维

该项目内置了多个运维管理面板（已在 IngressRoute 中配置域名）：

* **Traefik Dashboard**: 管理入口流量和中间件。
* **Homepage**: 项目的导航中心。
* **Dozzle**: 实时查看 Pod 日志。
* **Gotify**: 接收部署和运行时的消息通知。

### 常用命令示例

```bash
# 进入脚本目录
cd k8s/scripts

# 部署开发环境并验证
./deploy.sh -e dev && ./verify.sh

# 查看所有组件的状态
kubectl get pods,svc,ingressroute -n lunchbox

# 手动更新配置而不重新部署
helm upgrade lunchbox ../helm/lunchbox -f ../helm/lunchbox/values-dev.yaml -n lunchbox
```

## 下一步建议

如果您正在进行配置调整：

1. **域名修改**：优先编辑 `values.yaml` 中的 `global.domain`。
2. **资源调整**：如需增加 PHP-FPM 副本，修改 `values-*.yaml` 中的 `phpFpm.replicaCount`。
3. **安全性**：参考 [SECURITY.md](SECURITY.md) 完成生产环境的加固（如修改数据库默认密码）。

您可以查看 [STATUS.md](../STATUS.md) 了解目前各项任务的进度及待办事项。
