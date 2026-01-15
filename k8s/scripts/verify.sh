#!/bin/bash

# Lunchbox Kubernetes 验证脚本
# 用途：验证部署状态和健康检查

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 默认值
NAMESPACE="lunchbox"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  -n, --namespace NS   命名空间 [默认: lunchbox]"
            echo "  -h, --help           显示帮助信息"
            exit 0
            ;;
        *)
            print_error "未知参数: $1"
            exit 1
            ;;
    esac
done

print_info "========================================="
print_info "Lunchbox 部署验证"
print_info "========================================="
print_info "命名空间: $NAMESPACE"
print_info "========================================="
echo

# 检查命名空间
print_info "检查命名空间..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_success "命名空间存在: $NAMESPACE"
else
    print_error "命名空间不存在: $NAMESPACE"
    exit 1
fi
echo

# 检查 Pod 状态
print_info "检查 Pod 状态..."
PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null)

if [ -z "$PODS" ]; then
    print_error "没有找到任何 Pod"
    exit 1
fi

TOTAL_PODS=$(echo "$PODS" | wc -l)
RUNNING_PODS=$(echo "$PODS" | grep -c "Running" || true)
PENDING_PODS=$(echo "$PODS" | grep -c "Pending" || true)
FAILED_PODS=$(echo "$PODS" | grep -c -E "Error|CrashLoopBackOff|ImagePullBackOff" || true)

echo "  总计: $TOTAL_PODS"
echo "  运行中: $RUNNING_PODS"
echo "  等待中: $PENDING_PODS"
echo "  失败: $FAILED_PODS"

if [ "$FAILED_PODS" -gt 0 ]; then
    print_error "有 $FAILED_PODS 个 Pod 处于失败状态"
    echo
    print_info "失败的 Pod:"
    kubectl get pods -n "$NAMESPACE" | grep -E "Error|CrashLoopBackOff|ImagePullBackOff"
else
    print_success "所有 Pod 状态正常"
fi
echo

# 检查 Service
print_info "检查 Service..."
SERVICES=$(kubectl get svc -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$SERVICES" -gt 0 ]; then
    print_success "找到 $SERVICES 个 Service"
    kubectl get svc -n "$NAMESPACE"
else
    print_warning "没有找到 Service"
fi
echo

# 检查 PVC
print_info "检查 PersistentVolumeClaim..."
PVCS=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null)
if [ -n "$PVCS" ]; then
    BOUND_PVCS=$(echo "$PVCS" | grep -c "Bound" || true)
    TOTAL_PVCS=$(echo "$PVCS" | wc -l)
    
    if [ "$BOUND_PVCS" -eq "$TOTAL_PVCS" ]; then
        print_success "所有 PVC 已绑定 ($BOUND_PVCS/$TOTAL_PVCS)"
    else
        print_warning "部分 PVC 未绑定 ($BOUND_PVCS/$TOTAL_PVCS)"
    fi
    kubectl get pvc -n "$NAMESPACE"
else
    print_info "没有 PVC"
fi
echo

# 检查 IngressRoute
print_info "检查 IngressRoute..."
INGRESS_ROUTES=$(kubectl get ingressroute -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$INGRESS_ROUTES" -gt 0 ]; then
    print_success "找到 $INGRESS_ROUTES 个 IngressRoute"
    kubectl get ingressroute -n "$NAMESPACE"
else
    print_warning "没有找到 IngressRoute"
fi
echo

# 检查关键服务的健康状态
print_info "检查关键服务健康状态..."

check_service_health() {
    local service=$1
    local port=$2
    local path=${3:-"/"}
    
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app="$service" --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -z "$pod" ]; then
        print_warning "$service: Pod 不存在"
        return
    fi
    
    local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    
    if [ "$status" = "Running" ]; then
        print_success "$service: 运行中"
    else
        print_error "$service: 状态异常 ($status)"
    fi
}

check_service_health "postgres" "5432"
check_service_health "redis" "6379"
check_service_health "meilisearch" "7700"
check_service_health "minio" "9000"
check_service_health "php-fpm" "80"
check_service_health "authelia" "9091"
echo

# 检查最近的事件
print_info "检查最近的事件（最近 10 条）..."
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
echo

# 总结
print_info "========================================="
if [ "$FAILED_PODS" -eq 0 ] && [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
    print_success "验证通过！所有服务运行正常"
else
    print_warning "验证完成，但存在一些问题"
    print_info "请检查上述输出以获取详细信息"
fi
print_info "========================================="
