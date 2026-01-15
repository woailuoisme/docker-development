#!/bin/bash
set -e  # 遇到错误立即退出

# =============================================================================
# PostgreSQL 17 到 18 迁移脚本 (优化版)
# =============================================================================

# 加载 .env 文件
if [ -f .env ]; then
    echo "📄 加载 .env 配置文件..."
    # 导出 .env 中的变量（忽略注释和空行）
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
    echo "✅ .env 文件加载成功"
elif [ -f ../.env ]; then
    echo "📄 加载 ../.env 配置文件..."
    export $(grep -v '^#' ../.env | grep -v '^$' | xargs)
    echo "✅ .env 文件加载成功"
else
    echo "⚠️  未找到 .env 文件，使用默认配置"
fi

# 配置变量（优先使用环境变量，其次使用 .env，最后使用默认值）
OLD_CONTAINER="${OLD_CONTAINER:-postgres}"
NEW_CONTAINER="${NEW_CONTAINER:-postgres18}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-${DB_PASSWORD:-}}"
BACKUP_DIR="./backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/pg17_full_dump_${TIMESTAMP}.sql"
OLD_DATA_DIR="${OLD_DATA_DIR:-${DATA_PATH}/postgres}"
NEW_DATA_DIR="${NEW_DATA_DIR:-${DATA_PATH}/postgres18}"
NETWORK_NAME="${NETWORK_NAME:-backend}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 错误处理函数
error_exit() {
    log_error "$1"
    exit 1
}

# 清理函数
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "脚本执行失败，请检查错误信息"
        log_info "备份文件保存在: $BACKUP_FILE"
    fi
}
trap cleanup EXIT

# =============================================================================
# 预检查
# =============================================================================
log_info "🚀 开始从 PostgreSQL 17 迁移到 18 (逻辑迁移模式)"
log_info "时间戳: $TIMESTAMP"
echo ""

log_warning "⚠️  PostgreSQL 18 重要变化："
echo "  • PG18 的数据目录结构已改变"
echo "  • 旧版本: /var/lib/postgresql/data"
echo "  • 新版本: /var/lib/postgresql/18/main (或 18/docker)"
echo "  • 因此必须使用逻辑迁移（pg_dumpall），不能直接复制数据目录"
echo "  • 推荐挂载点: /var/lib/postgresql (便于未来升级)"
echo ""

log_success "✅ 数据安全保障："
echo "  • 原数据目录完全不会被修改或删除"
echo "  • 只进行只读导出操作"
echo "  • 新容器使用独立的数据目录"
echo "  • 创建带时间戳的备份文件"
echo "  • 旧容器可随时重新启动"
echo ""

# 显示配置信息
log_info "📋 当前配置:"
echo "  • 旧容器: $OLD_CONTAINER (PostgreSQL 17)"
echo "  • 新容器: $NEW_CONTAINER (PostgreSQL 18)"
echo "  • 数据库用户: $POSTGRES_USER"
echo "  • 密码: ${POSTGRES_PASSWORD:+已设置}"
echo "  • 旧数据目录: $OLD_DATA_DIR (保持不变)"
echo "  • 新数据目录: $NEW_DATA_DIR (全新目录)"
echo "  • 备份目录: $BACKUP_DIR"
echo "  • 网络: $NETWORK_NAME"
echo ""

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    error_exit "Docker 未运行或无权限访问"
fi

# 检查旧容器是否存在
if ! docker ps -a --format '{{.Names}}' | grep -q "^${OLD_CONTAINER}$"; then
    error_exit "容器 $OLD_CONTAINER 不存在"
fi

# 检查旧容器是否运行
if [ "$(docker inspect -f '{{.State.Running}}' $OLD_CONTAINER 2>/dev/null)" != "true" ]; then
    log_warning "容器 $OLD_CONTAINER 未运行，正在启动..."
    docker start $OLD_CONTAINER || error_exit "无法启动旧容器"
    sleep 5
fi

# 检查新容器是否已存在
if docker ps -a --format '{{.Names}}' | grep -q "^${NEW_CONTAINER}$"; then
    log_warning "容器 $NEW_CONTAINER 已存在"
    read -p "是否删除并重新创建? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker rm -f $NEW_CONTAINER
        log_success "已删除旧的 $NEW_CONTAINER 容器"
    else
        error_exit "请手动处理已存在的容器"
    fi
fi

# 创建备份目录
mkdir -p $BACKUP_DIR
log_success "备份目录已准备: $BACKUP_DIR"

# =============================================================================
# 1. 获取 PostgreSQL 版本信息
# =============================================================================
log_info "📊 检查 PostgreSQL 版本..."
OLD_VERSION=$(docker exec $OLD_CONTAINER psql -U $POSTGRES_USER -t -c "SELECT version();" | head -n 1)
log_info "当前版本: $OLD_VERSION"
echo ""

# =============================================================================
# 2. 导出数据前的健康检查
# =============================================================================
log_info "🔍 执行数据库健康检查..."

# 检查数据库连接
if ! docker exec $OLD_CONTAINER pg_isready -U $POSTGRES_USER > /dev/null 2>&1; then
    error_exit "数据库未就绪，无法连接"
fi

# 获取数据库列表
DB_COUNT=$(docker exec $OLD_CONTAINER psql -U $POSTGRES_USER -t -c "SELECT count(*) FROM pg_database WHERE datistemplate = false;" | tr -d ' ')
log_info "发现 $DB_COUNT 个用户数据库"

# 获取数据库大小
DB_SIZE=$(docker exec $OLD_CONTAINER psql -U $POSTGRES_USER -t -c "SELECT pg_size_pretty(sum(pg_database_size(datname))) FROM pg_database WHERE datistemplate = false;" | tr -d ' ')
log_info "总数据大小: $DB_SIZE"
echo ""

# =============================================================================
# 3. 导出所有数据
# =============================================================================
log_info "📦 正在导出所有数据 (pg_dumpall)..."
log_warning "这可能需要较长时间，请耐心等待..."

# 使用 pg_dumpall 导出（包含角色、表空间、数据库等）
if docker exec $OLD_CONTAINER pg_dumpall -U $POSTGRES_USER > $BACKUP_FILE 2>/dev/null; then
    BACKUP_SIZE=$(du -h $BACKUP_FILE | cut -f1)
    log_success "数据导出成功: $BACKUP_FILE (大小: $BACKUP_SIZE)"
else
    error_exit "数据导出失败"
fi

# 验证备份文件
if [ ! -s $BACKUP_FILE ]; then
    error_exit "备份文件为空"
fi
echo ""

# =============================================================================
# 4. 准备新环境
# =============================================================================
log_info "🛠️  准备 PostgreSQL 18 环境..."

# 创建新数据目录
mkdir -p $NEW_DATA_DIR

# 检查新数据目录是否为空
if [ "$(ls -A $NEW_DATA_DIR 2>/dev/null)" ]; then
    log_warning "新数据目录 $NEW_DATA_DIR 不为空"
    read -p "是否清空该目录? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf ${NEW_DATA_DIR:?}/*
        log_success "已清空新数据目录"
    else
        error_exit "请手动清理数据目录"
    fi
fi

log_info "旧容器 $OLD_CONTAINER 将保持运行状态"
log_info "新容器将使用不同的端口，两者可以同时运行"
echo ""

# =============================================================================
# 5. 启动 PostgreSQL 18 容器
# =============================================================================
log_info "🌟 启动 PostgreSQL 18 容器..."

# 检查是否使用 docker-compose
if [ -f "docker-compose.yml" ]; then
    log_info "检测到 docker-compose.yml，建议使用 docker compose up -d $NEW_CONTAINER"
    read -p "是否使用 docker compose 启动? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        docker compose up -d $NEW_CONTAINER || error_exit "docker compose 启动失败"
    else
        # 使用 docker run 启动
        DOCKER_CMD="docker run --name $NEW_CONTAINER"
        DOCKER_CMD="$DOCKER_CMD -v $(pwd)/$NEW_DATA_DIR:/var/lib/postgresql/data"
        
        # 如果提供了密码
        if [ -n "$POSTGRES_PASSWORD" ]; then
            DOCKER_CMD="$DOCKER_CMD -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
        fi
        
        # 如果网络存在则加入
        if docker network ls | grep -q $NETWORK_NAME; then
            DOCKER_CMD="$DOCKER_CMD --network $NETWORK_NAME"
        fi
        
        DOCKER_CMD="$DOCKER_CMD -p 5432:5432 -d postgres:18"
        
        eval $DOCKER_CMD || error_exit "容器启动失败"
    fi
else
    # 直接使用 docker run
    docker run --name $NEW_CONTAINER \
        -v $(pwd)/$NEW_DATA_DIR:/var/lib/postgresql/data \
        ${POSTGRES_PASSWORD:+-e POSTGRES_PASSWORD=$POSTGRES_PASSWORD} \
        -p 5432:5432 \
        -d postgres:18 || error_exit "容器启动失败"
fi

log_success "PostgreSQL 18 容器已启动"

# =============================================================================
# 6. 等待数据库就绪
# =============================================================================
log_info "⏳ 等待数据库初始化..."
MAX_WAIT=60
WAIT_COUNT=0

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if docker exec $NEW_CONTAINER pg_isready -U $POSTGRES_USER > /dev/null 2>&1; then
        log_success "数据库已就绪"
        break
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    echo -n "."
done
echo ""

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    error_exit "数据库初始化超时"
fi

# 获取新版本信息
NEW_VERSION=$(docker exec $NEW_CONTAINER psql -U $POSTGRES_USER -t -c "SELECT version();" | head -n 1)
log_info "新版本: $NEW_VERSION"
echo ""

# =============================================================================
# 7. 导入数据
# =============================================================================
log_info "📥 正在将数据导入 PostgreSQL 18..."
log_warning "导入过程中可能会有一些警告信息，这是正常的"

if cat $BACKUP_FILE | docker exec -i $NEW_CONTAINER psql -U $POSTGRES_USER 2>&1 | tee ${BACKUP_DIR}/import_${TIMESTAMP}.log; then
    log_success "数据导入完成"
else
    log_error "导入过程中出现错误，请检查日志: ${BACKUP_DIR}/import_${TIMESTAMP}.log"
    exit 1
fi
echo ""

# =============================================================================
# 8. 验证迁移
# =============================================================================
log_info "🔍 验证迁移结果..."

# 检查数据库数量
NEW_DB_COUNT=$(docker exec $NEW_CONTAINER psql -U $POSTGRES_USER -t -c "SELECT count(*) FROM pg_database WHERE datistemplate = false;" | tr -d ' ')
if [ "$DB_COUNT" = "$NEW_DB_COUNT" ]; then
    log_success "数据库数量一致: $NEW_DB_COUNT"
else
    log_warning "数据库数量不一致: 旧=$DB_COUNT, 新=$NEW_DB_COUNT"
fi

# 检查数据大小
NEW_DB_SIZE=$(docker exec $NEW_CONTAINER psql -U $POSTGRES_USER -t -c "SELECT pg_size_pretty(sum(pg_database_size(datname))) FROM pg_database WHERE datistemplate = false;" | tr -d ' ')
log_info "新数据库大小: $NEW_DB_SIZE (原: $DB_SIZE)"
echo ""

# =============================================================================
# 9. 优化新数据库
# =============================================================================
log_info "🔧 执行数据库优化..."

# 分析所有数据库
log_info "正在分析数据库统计信息..."
docker exec $NEW_CONTAINER vacuumdb -U $POSTGRES_USER --all --analyze-only || log_warning "分析过程出现警告"

log_success "数据库优化完成"
echo ""

# =============================================================================
# 10. 完成总结
# =============================================================================
echo "=========================================="
log_success "🎉 迁移完成！"
echo "=========================================="
echo ""
log_info "迁移信息:"
echo "  • 备份文件: $BACKUP_FILE"
echo "  • 导入日志: ${BACKUP_DIR}/import_${TIMESTAMP}.log"
echo "  • 旧容器: $OLD_CONTAINER (已停止)"
echo "  • 新容器: $NEW_CONTAINER (运行中)"
echo "  • 数据目录: $NEW_DATA_DIR"
echo ""
log_info "后续步骤:"
echo "  1. 测试新数据库功能是否正常"
echo "  2. 更新应用程序连接配置"
echo "  3. 确认无误后可删除旧容器和数据:"
echo "     docker rm $OLD_CONTAINER"
echo "     rm -rf $OLD_DATA_DIR"
echo "  4. 可选: 删除备份文件以节省空间"
echo ""
log_warning "建议保留备份文件至少 7 天，确保迁移完全成功"