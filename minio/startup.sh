#!/bin/bash

# =========================================================
# MinIO 简化启动脚本
# 专注于服务启动，避免复杂初始化导致容器重启
# =========================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 简单日志函数
log() {
    local level="$1"
    local message="$2"
    local color="$NC"

    case "$level" in
        "INFO") color="$BLUE" ;;
        "SUCCESS") color="$GREEN" ;;
        "WARNING") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
    esac

    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${color}[$level]${NC} $message"
}

log "INFO" "=========================================="
log "INFO" "   MinIO 启动脚本开始执行"
log "INFO" "=========================================="

# 使用基础镜像的环境变量
log "INFO" "环境变量:"
log "INFO" "  - MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}"
log "INFO" "  - MINIO_DATA_PATH: ${MINIO_DATA_PATH:-/data}"
log "INFO" "  - MINIO_CONSOLE_PORT: ${MINIO_CONSOLE_PORT:-9001}"
log "INFO" "  - MINIO_BUCKETS: ${MINIO_BUCKETS}"
log "INFO" "  - ENABLE_INITIALIZE_BUCKETS: ${ENABLE_INITIALIZE_BUCKETS:-false}"

# 检查数据目录
if [ ! -d "${MINIO_DATA_PATH:-/data}" ]; then
    log "INFO" "创建数据目录: ${MINIO_DATA_PATH:-/data}"
    mkdir -p "${MINIO_DATA_PATH:-/data}"
fi

log "SUCCESS" "启动 MinIO 服务..."
log "INFO" "命令: minio server ${MINIO_DATA_PATH:-/data} --console-address :${MINIO_CONSOLE_PORT:-9001}"

# 在后台启动 MinIO 服务进行初始化
minio server "${MINIO_DATA_PATH:-/data}" --console-address ":${MINIO_CONSOLE_PORT:-9001}" &
MINIO_PID=$!

log "SUCCESS" "MinIO 服务已启动 (PID: $MINIO_PID)"

# 等待服务就绪
log "INFO" "等待 MinIO 服务就绪..."
until curl -s "http://localhost:9000/minio/health/live" > /dev/null 2>&1; do
    sleep 2
done

log "SUCCESS" "MinIO 服务已就绪"

# 检查并安装 mc 客户端
install_mc_client() {
    if command -v mc &> /dev/null; then
        log "SUCCESS" "mc 客户端已安装"
        return 0
    fi

    log "INFO" "安装 mc 客户端..."
    wget -q -O /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x /usr/local/bin/mc
    if command -v mc &> /dev/null; then
        log "SUCCESS" "mc 客户端安装成功"
        return 0
    else
        log "WARNING" "mc 客户端安装失败，跳过存储桶初始化"
        return 1
    fi
}

# 初始化存储桶
initialize_buckets() {
    log "INFO" "开始初始化存储桶..."

    # 设置别名
    mc alias set local http://localhost:9000 "${MINIO_ROOT_USER:-minioadmin}" "${MINIO_ROOT_PASSWORD:-minioadmin}"

    # 定义存储桶配置 - 使用环境变量或默认值
    local default_buckets=(
        "backup:private:备份存储桶"
        "asset:public:资源存储桶"
        "app:public:应用存储桶"
        "temp:public:临时文件存储桶"
        "logs:private:日志存储桶"
    )

    # 解析环境变量中的存储桶配置
    local buckets=()
    if [ -n "$MINIO_BUCKETS" ]; then
        log "INFO" "使用环境变量中的存储桶配置"
        IFS=',' read -ra bucket_configs <<< "$MINIO_BUCKETS"
        for bucket_config in "${bucket_configs[@]}"; do
            buckets+=("$bucket_config")
        done
    else
        log "INFO" "使用默认存储桶配置"
        buckets=("${default_buckets[@]}")
    fi

    for bucket_config in "${buckets[@]}"; do
        IFS=':' read -r bucket_name policy description <<< "$bucket_config"
        log "INFO" "配置存储桶: $bucket_name ($description)"

        # 创建存储桶（如果不存在）
        if ! mc ls "local/$bucket_name" >/dev/null 2>&1; then
            mc mb "local/$bucket_name"
            log "SUCCESS" "创建存储桶: $bucket_name"
        else
            log "INFO" "存储桶已存在: $bucket_name"
        fi

        # 设置访问策略
        mc anonymous set "$policy" "local/$bucket_name" && \
        log "SUCCESS" "设置策略: $bucket_name -> $policy"
    done

    log "SUCCESS" "存储桶初始化完成"
    log "INFO" "存储桶列表:"
    mc ls local
}

# 执行初始化
if [ "${ENABLE_INITIALIZE_BUCKETS:-false}" = "true" ]; then
    log "INFO" "ENABLE_INITIALIZE_BUCKETS=true，执行存储桶初始化"
    if install_mc_client; then
        initialize_buckets
    else
        log "WARNING" "跳过存储桶初始化"
    fi
else
    log "INFO" "ENABLE_INITIALIZE_BUCKETS=false，跳过存储桶初始化"
fi

# 停止后台进程并重新在前台启动
log "INFO" "停止后台 MinIO 进程..."
kill $MINIO_PID
wait $MINIO_PID 2>/dev/null

log "SUCCESS" "在前台启动 MinIO 服务..."
# 使用 exec 让 MinIO 进程成为 PID 1，这样容器生命周期与 MinIO 进程绑定
exec minio server "${MINIO_DATA_PATH:-/data}" --console-address ":${MINIO_CONSOLE_PORT:-9001}"
