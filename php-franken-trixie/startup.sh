#!/bin/bash

# Laravel Octane with FrankenPHP 启动脚本
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

# 1. 检查应用目录
check_app_directory() {
    [ -d "${APP_PATH}" ] && [ -f "${APP_PATH}/artisan" ] || { log_error "应用检查失败: ${APP_PATH}"; exit 1; }
    log_success "应用目录检查通过"
}

# 2. 前台启动 FrankenPHP
start_frankenphp() {
    log_info "启动 FrankenPHP..."
    cd "${APP_PATH}"
    exec php artisan octane:frankenphp \
        --port="${APP_PORT}" \
        --host="${OCTANE_HOST}" \
        --workers="${OCTANE_WORKERS}" \
        --admin-port="${OCTANE_ADMIN_PORT}" \
        --max-requests="${OCTANE_MAX_REQUESTS}" \
        --env="${APP_ENV}" \
        $([ "${ENABLE_OCTANE_LOG_LEVEL}" != "false" ] && echo "--log-level=${OCTANE_LOG_LEVEL}") \
        $([ "${WATCH}" = "true" ] && echo "--watch") \
        $([ "${OCTANE_POLL}" = "true" ] && echo "--poll") \
        $([ "${OCTANE_HTTPS}" = "true" ] && echo "--https") \
        $([ "${OCTANE_HTTP_REDIRECT}" = "true" ] && echo "--http-redirect")
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止服务..."; exit 0' SIGTERM SIGINT

# 主流程
log_info "启动 Laravel Octane with FrankenPHP 服务..."
check_app_directory
start_frankenphp
