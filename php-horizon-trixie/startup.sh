#!/bin/bash

# Laravel Horizon 启动脚本
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

# 2. 直接运行 Horizon
start_horizon() {
    log_info "正在直接运行 Laravel Horizon..."
    cd "${APP_PATH}"
    log_info "执行命令: php artisan horizon --environment=\"${APP_ENV}\" --env=\"${APP_ENV}\""
    exec php artisan horizon --environment="${APP_ENV}" --env="${APP_ENV}"
}


# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止 Horizon..."; exit 0' SIGTERM SIGINT

# 主流程
log_info "启动 Laravel Horizon 服务..."
check_app_directory
start_horizon
