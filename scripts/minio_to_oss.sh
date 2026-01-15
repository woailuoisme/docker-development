#!/bin/bash
set -e  # 遇到错误立即退出

# =============================================================================
# MinIO 到阿里云 OSS 数据迁移脚本
# =============================================================================

# 加载 .env 文件
if [ -f .env ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
elif [ -f ../.env ]; then
    export $(grep -v '^#' ../.env | grep -v '^$' | xargs)
fi

# 配置
MINIO_ALIAS="${MINIO_ALIAS:-minio}"
MINIO_URL="${MINIO_URL:-http://localhost:9526}"
MINIO_KEY="${MINIO_ROOT_USER:-minio}"
MINIO_SECRET="${MINIO_ROOT_PASSWORD:-}"
MINIO_BUCKET="${MINIO_BUCKET:-}"

OSS_ALIAS="${OSS_ALIAS:-ali_oss}"
OSS_ENDPOINT="${OSS_ENDPOINT:-https://oss-cn-heyuan.aliyuncs.com}"
OSS_KEY="${ALIYUN_ACCESS_KEY_ID:-}"
OSS_SECRET="${ALIYUN_ACCESS_KEY_SECRET:-}"
OSS_BUCKET="${OSS_BUCKET:-}"

BANDWIDTH_LIMIT="${BANDWIDTH_LIMIT:-}"

LOG_DIR="./logs/oss_migration"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/migration_${TIMESTAMP}.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

# 预检查
mkdir -p "$LOG_DIR"

if ! command -v mc &> /dev/null; then
    log_error "mc 未安装"
fi

[ -z "$MINIO_SECRET" ] && log_error "MinIO Secret 未设置"
[ -z "$OSS_KEY" ] || [ -z "$OSS_SECRET" ] && log_error "OSS 密钥未设置"
[ -z "$MINIO_BUCKET" ] && log_error "MinIO Bucket 未指定"
[ -z "$OSS_BUCKET" ] && log_error "OSS Bucket 未指定"

log_info "MinIO: $MINIO_BUCKET -> OSS: $OSS_BUCKET"

# 配置别名
mc alias set $MINIO_ALIAS $MINIO_URL $MINIO_KEY $MINIO_SECRET >> "$LOG_FILE" 2>&1 || log_error "MinIO 配置失败"
mc alias set $OSS_ALIAS $OSS_ENDPOINT $OSS_KEY $OSS_SECRET >> "$LOG_FILE" 2>&1 || log_error "OSS 配置失败"

# 验证连接
mc ls $MINIO_ALIAS >> "$LOG_FILE" 2>&1 || log_error "MinIO 连接失败"
mc ls $OSS_ALIAS >> "$LOG_FILE" 2>&1 || log_error "OSS 连接失败"
mc ls $MINIO_ALIAS/$MINIO_BUCKET >> "$LOG_FILE" 2>&1 || log_error "源 Bucket 不存在"

# 检查目标 Bucket
if mc ls $OSS_ALIAS/$OSS_BUCKET >> "$LOG_FILE" 2>&1; then
    log_info "目标 Bucket 已存在，将直接使用"
else
    log_info "目标 Bucket 不存在，尝试创建..."
    if ! mc mb $OSS_ALIAS/$OSS_BUCKET >> "$LOG_FILE" 2>&1; then
        log_error "创建失败，Bucket 名称可能已被占用或权限不足"
    fi
    log_success "目标 Bucket 创建成功"
fi

# 统计源数据
SOURCE_COUNT=$(mc ls --recursive $MINIO_ALIAS/$MINIO_BUCKET 2>/dev/null | wc -l | tr -d ' ')
log_info "源文件: $SOURCE_COUNT 个"

[ "$SOURCE_COUNT" -eq 0 ] && { log_warning "源为空，无需迁移"; exit 0; }

# 确认
read -p "开始迁移? (y/N): " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && { log_info "已取消"; exit 0; }

# 执行迁移
log_info "开始同步..."
START_TIME=$(date +%s)

MIRROR_CMD="mc mirror --overwrite"
[ -n "$BANDWIDTH_LIMIT" ] && MIRROR_CMD="$MIRROR_CMD --limit-upload $BANDWIDTH_LIMIT"
MIRROR_CMD="$MIRROR_CMD $MINIO_ALIAS/$MINIO_BUCKET $OSS_ALIAS/$OSS_BUCKET"

if eval $MIRROR_CMD 2>&1 | tee -a "$LOG_FILE"; then
    DURATION=$(($(date +%s) - START_TIME))
    log_success "同步完成 (耗时: ${DURATION}s)"
else
    log_error "同步失败"
fi

# 验证
TARGET_COUNT=$(mc ls --recursive $OSS_ALIAS/$OSS_BUCKET 2>/dev/null | wc -l | tr -d ' ')

if [ "$SOURCE_COUNT" -eq "$TARGET_COUNT" ]; then
    log_success "验证通过: $TARGET_COUNT 个文件"
else
    log_warning "文件数不匹配 (源: $SOURCE_COUNT, 目标: $TARGET_COUNT)"
fi

log_info "日志: $LOG_FILE"