#!/bin/bash
# Traefik Ingress Controller 安装脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        error "$1 未安装，请先安装 $1"
    fi
}

# 检查必要的工具
info "检查必要的工具..."
check_command kubectl
check_command helm

# 检查 Kubernetes 连接
info "检查 Kubernetes 连接..."
if ! kubectl cluster-info &> /dev/null; then
    error "无法连接到 Kubernetes 集群"
fi

# 创建 traefik 命名空间
info "创建 traefik 命名空间..."
kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -

# 添加 Traefik Helm 仓库
info "添加 Traefik Helm 仓库..."
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 检查是否已安装 Traefik
if helm list -n traefik | grep -q traefik; then
    warn "Traefik 已安装，将进行升级..."
    ACTION="upgrade"
else
    info "开始安装 Traefik..."
    ACTION="install"
fi

# 安装或升级 Traefik
helm $ACTION traefik traefik/traefik \
    --namespace traefik \
    --values ../helm/traefik-values.yaml \
    --wait \
    --timeout 5m

# 等待 Traefik Pod 就绪
info "等待 Traefik Pod 就绪..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=traefik \
    -n traefik \
    --timeout=300s

# 获取 Traefik Service 信息
info "Traefik Service 信息:"
kubectl get svc -n traefik traefik

# 获取 LoadBalancer IP (如果使用 LoadBalancer)
EXTERNAL_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$EXTERNAL_IP" ]; then
    info "Traefik LoadBalancer IP: $EXTERNAL_IP"
else
    warn "LoadBalancer IP 尚未分配，如果使用 NodePort，请查看 NodePort 端口"
    kubectl get svc -n traefik traefik -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}'
    echo ""
fi

# 创建 Dashboard 认证中间件
info "创建 Traefik Dashboard 认证中间件..."
cat <<EOF | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
  namespace: traefik
spec:
  basicAuth:
    secret: traefik-dashboard-auth
EOF

# 创建 Dashboard 认证 Secret (用户名: admin, 密码: admin)
# 生产环境请修改密码！
info "创建 Dashboard 认证 Secret..."
kubectl create secret generic traefik-dashboard-auth \
    --from-literal=users='admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/' \
    -n traefik \
    --dry-run=client -o yaml | kubectl apply -f -

info "Traefik 安装完成！"
info "Dashboard 访问地址: https://traefik.example.com (请修改 DNS 或 hosts)"
info "Dashboard 用户名: admin"
info "Dashboard 密码: admin (生产环境请修改！)"
