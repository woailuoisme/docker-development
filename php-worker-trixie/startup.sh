#!/bin/bash

# Laravel Queue Worker 启动脚本
set -e

# 日志工具
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
log() { echo -e "${1}[$(date '+%Y-%m-%d %H:%M:%S %z')] [${2}]${NC} ${3}"; }
log_info()    { log "${BLUE}" "INFO" "$1"; }
log_success() { log "${GREEN}" "SUCCESS" "$1"; }
log_warning() { log "${YELLOW}" "WARNING" "$1"; }
log_error()   { log "${RED}" "ERROR" "$1"; }

# 变量
readonly APP_PATH=${APP_PATH:-/var/www/lunchbox}
readonly APP_ENV=${APP_ENV:-docker}
readonly QUEUE_CONNECTION=${QUEUE_CONNECTION:-redis}
readonly QUEUE_NAME=${QUEUE_NAME:-default}
readonly QUEUE_TRIES=${QUEUE_TRIES:-3}
readonly QUEUE_TIMEOUT=${QUEUE_TIMEOUT:-60}
readonly QUEUE_MEMORY=${QUEUE_MEMORY:-128}

# 1. 检查应用目录
check_app_directory() {
    [ -d "${APP_PATH}" ] && [ -f "${APP_PATH}/artisan" ] || { log_error "应用检查失败: ${APP_PATH}"; exit 1; }
    log_success "应用目录检查通过"
}

# 2. 显示配置
show_config() {
    log_info "=== Laravel Queue Worker 启动配置 ==="
    log_info "应用路径: ${APP_PATH}"
    log_info "运行环境: ${APP_ENV}"
    log_info "队列连接: ${QUEUE_CONNECTION}"
    log_info "队列名称: ${QUEUE_NAME}"
    log_info "重试次数: ${QUEUE_TRIES}"
    log_info "超时时间: ${QUEUE_TIMEOUT}s"
    log_info "内存限制: ${QUEUE_MEMORY}MB"
    log_info "======================================"
}

# 3. 直接运行 Queue Worker
start_worker() {
    log_info "正在直接运行 Laravel Queue Worker..."
    cd "${APP_PATH}"
    log_info "执行命令: php artisan queue:work \"${QUEUE_CONNECTION}\" --queue=\"${QUEUE_NAME}\" --tries=${QUEUE_TRIES} --timeout=${QUEUE_TIMEOUT} --memory=${QUEUE_MEMORY} --env=\"${APP_ENV}\""
    exec php artisan queue:work "${QUEUE_CONNECTION}" --queue="${QUEUE_NAME}" --tries=${QUEUE_TRIES} --timeout=${QUEUE_TIMEOUT} --memory=${QUEUE_MEMORY} --env="${APP_ENV}"
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止 Queue Worker..."; exit 0' SIGTERM SIGINT

# 主流程
log_info "启动 Laravel Queue Worker 服务..."
show_config
check_app_directory
start_worker
