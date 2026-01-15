#!/bin/bash

# Lunchbox Kubernetes 清理脚本
# 用途：清理 Kubernetes 资源

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 默认值
NAMESPACE="lunchbox"
RELEASE_NAME="lunchbox"
DELETE_NAMESPACE=false
DELETE_PVC=false
FORCE=false

# 显示帮助
show_help() {
    cat << EOF
Lunchbox Kubernetes 清理脚本

用法:
    $0 [选项]

选项:
    -n, --namespace NS     指定命名空间，默认: lunchbox
    -r, --release NAME     指定 Helm release 名称，默认: lunchbox
    --delete-namespace     删除整个命名空间
    --delete-pvc           删除 PersistentVolumeClaim（数据将丢失！）
    -f, --force            强制删除，不提示确认
    -h, --help             显示此帮助信息

示例:
    # 仅卸载 Helm release
    $0

    # 删除命名空间和所有资源
    $0 --delete-namespace

    # 删除所有资源包括数据
    $0 --delete-namespace --delete-pvc

    # 强制删除不提示
    $0 --delete-namespace --delete-pvc --force

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        --delete-namespace)
            DELETE_NAMESPACE=true
            shift
            ;;
        --delete-pvc)
            DELETE_PVC=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

print_info "========================================="
print_info "Lunchbox Kubernetes 清理"
print_info "========================================="
print_info "命名空间: $NAMESPACE"
print_info "Release: $RELEASE_NAME"
print_info "删除命名空间: $DELETE_NAMESPACE"
print_info "删除 PVC: $DELETE_PVC"
print_info "========================================="
echo

# 确认操作
if [ "$FORCE" = false ]; then
    print_warning "此操作将删除以下资源："
    echo "  - Helm Release: $RELEASE_NAME"
    
    if [ "$DELETE_PVC" = true ]; then
        echo "  - PersistentVolumeClaim（数据将永久丢失！）"
    fi
    
    if [ "$DELETE_NAMESPACE" = true ]; then
        echo "  - 命名空间: $NAMESPACE（包含所有资源）"
    fi
    
    echo
    read -p "确认继续？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "操作已取消"
        exit 0
    fi
fi

echo

# 检查命名空间是否存在
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_warning "命名空间不存在: $NAMESPACE"
    exit 0
fi

# 卸载 Helm Release
print_info "卸载 Helm Release..."
if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
    print_success "Helm Release 已卸载: $RELEASE_NAME"
else
    print_warning "Helm Release 不存在: $RELEASE_NAME"
fi
echo

# 删除 PVC
if [ "$DELETE_PVC" = true ]; then
    print_info "删除 PersistentVolumeClaim..."
    
    PVCS=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
    
    if [ -n "$PVCS" ]; then
        for pvc in $PVCS; do
            print_info "删除 PVC: $pvc"
            kubectl delete pvc "$pvc" -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        done
        print_success "所有 PVC 已删除"
    else
        print_info "没有找到 PVC"
    fi
    echo
fi

# 删除命名空间
if [ "$DELETE_NAMESPACE" = true ]; then
    print_info "删除命名空间..."
    kubectl delete namespace "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    
    # 等待命名空间删除
    print_info "等待命名空间删除完成..."
    timeout=60
    elapsed=0
    
    while kubectl get namespace "$NAMESPACE" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "命名空间删除超时，可能需要手动清理"
            break
        fi
        
        echo -n "."
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    echo
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_success "命名空间已删除: $NAMESPACE"
    fi
else
    print_info "保留命名空间: $NAMESPACE"
    print_info "如需删除命名空间，请使用 --delete-namespace 选项"
fi

echo
print_info "========================================="
print_success "清理完成！"
print_info "========================================="

# 显示剩余资源
if [ "$DELETE_NAMESPACE" = false ]; then
    echo
    print_info "剩余资源:"
    kubectl get all -n "$NAMESPACE" 2>/dev/null || print_info "命名空间为空"
fi
