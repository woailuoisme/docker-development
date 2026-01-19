#!/bin/bash

# Laravel Octane with RoadRunner 启动脚本
# 直接通过命令行启动 RoadRunner

set -e

# 日志工具
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
log() { echo -e "${1}[$(date '+%Y-%m-%d %H:%M:%S %z')] [${2}]${NC} ${3}"; }
log_info()    { log "${BLUE}" "INFO" "$1"; }
log_success() { log "${GREEN}" "SUCCESS" "$1"; }
log_warning() { log "${YELLOW}" "WARNING" "$1"; }
log_error()   { log "${RED}" "ERROR" "$1"; }

# 全局变量
readonly APP_PATH=${APP_PATH:-/var/www/lunchbox}
readonly APP_ENV=${APP_ENV:-docker}
OCTANE_LOG_LEVEL=${OCTANE_LOG_LEVEL:-${LOG_LEVEL:-info}}

# 显示启动配置
show_config() {
    log_info "=== Laravel Octane 启动配置 ==="
    log_info "应用路径: ${APP_PATH}"
    log_info "运行环境: ${APP_ENV}"
    log_info "服务器: RoadRunner"
    log_info "端口: ${APP_PORT}"
    log_info "监听地址: ${OCTANE_HOST}"
    log_info "工作进程数: ${OCTANE_WORKERS}"
    log_info "最大请求数: ${OCTANE_MAX_REQUESTS}"
    log_info "文件监听: ${WATCH}"
    log_info "日志级别: ${OCTANE_LOG_LEVEL}"
    log_info "================================="
}

# 检查应用目录
check_app_directory() {
    if [ ! -d "${APP_PATH}" ]; then
        log_error "应用目录不存在: ${APP_PATH}"
        exit 1
    fi

    if [ ! -f "${APP_PATH}/artisan" ]; then
        log_error "artisan 文件不存在: ${APP_PATH}/artisan"
        exit 1
    fi

    log_success "应用目录检查通过"
}

# 直接运行 RoadRunner
start_direct() {
    log_info "正在直接运行 RoadRunner..."
    log_info "执行命令: php artisan octane:start --server=roadrunner"
    log_info "使用 RoadRunner 路径: ${OCTANE_RR_BINARY}"
    
    # 构建完整的启动命令
    local cmd="php artisan octane:start"
    cmd="${cmd} --server=${OCTANE_SERVER:-roadrunner}"
    cmd="${cmd} --env=${APP_ENV}"
    cmd="${cmd} --port=${APP_PORT}"
    cmd="${cmd} --host=${OCTANE_HOST}"
    cmd="${cmd} --workers=${OCTANE_WORKERS}"
    cmd="${cmd} --max-requests=${OCTANE_MAX_REQUESTS}"
    cmd="${cmd} --log-level=${OCTANE_LOG_LEVEL}"
    
    if [ "${WATCH}" = "true" ]; then
        cmd="${cmd} --watch"
    fi
    
    log_info "完整命令: ${cmd}"
    
    # 确保环境变量传递
    export OCTANE_SERVER="${OCTANE_SERVER:-roadrunner}"
    export OCTANE_HOST="${OCTANE_HOST}"
    export OCTANE_RR_BINARY="${OCTANE_RR_BINARY}"
    export OCTANE_WORKERS="${OCTANE_WORKERS}"
    export OCTANE_MAX_REQUESTS="${OCTANE_MAX_REQUESTS}"
    export OCTANE_LOG_LEVEL="${OCTANE_LOG_LEVEL}"
    
    exec ${cmd}
}

# 主函数
main() {
    log_info "启动 Laravel Octane with RoadRunner..."

    # 显示配置
    show_config

    # 检查应用目录
    check_app_directory

    # 切换到应用目录
    cd "${APP_PATH}"
    log_info "切换到应用目录: $(pwd)"

    # 直接启动
    start_direct
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止服务..."; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
