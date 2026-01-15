#!/bin/bash
# Lunchbox 快速部署脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 默认值
ENVIRONMENT="dev"
NAMESPACE="lunchbox"
RELEASE_NAME="lunchbox"
CHART_PATH="../helm/lunchbox"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  -e, --env ENV        环境 (dev|staging|prod) [默认: dev]"
            echo "  -n, --namespace NS   命名空间 [默认: lunchbox]"
            echo "  -h, --help           显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 -e dev"
            echo "  $0 -e prod -n lunchbox-prod"
            exit 0
            ;;
        *)
            error "未知参数: $1"
            ;;
    esac
done

# 验证环境
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    error "无效的环境: $ENVIRONMENT (必须是 dev, staging 或 prod)"
fi

VALUES_FILE="values-${ENVIRONMENT}.yaml"

info "部署配置:"
echo "  环境: $ENVIRONMENT"
echo "  命名空间: $NAMESPACE"
echo "  Release: $RELEASE_NAME"
echo "  配置文件: $VALUES_FILE"
echo ""

# 检查工具
step "1/6 检查必要工具..."
command -v kubectl >/dev/null 2>&1 || error "kubectl 未安装"
command -v helm >/dev/null 2>&1 || error "helm 未安装"
info "✓ 工具检查通过"

# 检查 Kubernetes 连接
step "2/6 检查 Kubernetes 连接..."
kubectl cluster-info >/dev/null 2>&1 || error "无法连接到 Kubernetes 集群"
info "✓ Kubernetes 连接正常"

# 创建命名空间
step "3/6 创建命名空间..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
info "✓ 命名空间已创建: $NAMESPACE"

# 检查 Traefik
step "4/6 检查 Traefik Ingress Controller..."
if ! kubectl get deployment -n traefik traefik >/dev/null 2>&1; then
    warn "Traefik 未安装，正在安装..."
    ./install-traefik.sh
fi
info "✓ Traefik 已就绪"

# 部署应用
step "5/6 部署应用..."
if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    info "应用已存在，执行升级..."
    helm upgrade $RELEASE_NAME $CHART_PATH \
        -n $NAMESPACE \
        -f $CHART_PATH/values.yaml \
        -f $CHART_PATH/$VALUES_FILE \
        --wait \
        --timeout 10m
else
    info "执行全新安装..."
    helm install $RELEASE_NAME $CHART_PATH \
        -n $NAMESPACE \
        -f $CHART_PATH/values.yaml \
        -f $CHART_PATH/$VALUES_FILE \
        --wait \
        --timeout 10m
fi
info "✓ 应用部署完成"

# 验证部署
step "6/6 验证部署状态..."
echo ""
info "Pod 状态:"
kubectl get pods -n $NAMESPACE

echo ""
info "Service 状态:"
kubectl get svc -n $NAMESPACE

echo ""
info "PVC 状态:"
kubectl get pvc -n $NAMESPACE

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
info "下一步操作:"
echo "  1. 查看 Pod 日志: kubectl logs -n $NAMESPACE <pod-name>"
echo "  2. 进入容器: kubectl exec -it -n $NAMESPACE <pod-name> -- /bin/sh"
echo "  3. 查看事件: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo ""
warn "注意事项:"
echo "  - 请确保已配置正确的域名和 DNS"
echo "  - 请修改默认密码（生产环境）"
echo "  - 请配置正确的镜像仓库地址"
