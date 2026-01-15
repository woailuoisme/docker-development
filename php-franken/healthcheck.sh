#!/bin/bash

# Laravel Octane with FrankenPHP 健康检查脚本
# 用于 Docker 健康检测

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${GREEN}[${timestamp}] [HEALTH]${NC} $1" >&2
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${RED}[${timestamp}] [HEALTH_ERROR]${NC} $1" >&2
}

# 检查 Supervisor 进程（仅在启用时检查）
check_supervisor_process() {
    # 检查是否启用了 Supervisor
    if [ "${ENABLE_SUPERVISOR:-false}" = "true" ]; then
        if pgrep -f "supervisord" > /dev/null; then
            log_info "Supervisor 进程运行正常"
            return 0
        else
            log_error "Supervisor 进程未运行"
            return 1
        fi
    else
        log_info "Supervisor 未启用，跳过检查"
        return 0
    fi
}

# 检查 HTTP 服务
check_http_service() {
    local port=${APP_PORT:-8001}
    local timeout=5

    # 尝试连接 HTTP 服务
    if curl -f -s -m $timeout "http://localhost:${port}/live" > /dev/null 2>&1; then
        log_info "HTTP 服务web响应正常 (端口: ${port})"
        return 0
    elif curl -f -s -m $timeout "http://localhost:${port}/api/live" > /dev/null 2>&1; then
        log_info "HTTP 服务api响应正常 (端口: ${port})"
        return 0
    else
        log_error "HTTP 服务无响应 (端口: ${port})"
        return 1
    fi
}

# 检查应用目录
check_app_directory() {
    local app_path=${APP_PATH:-/var/www/lunchbox}

    if [ ! -d "$app_path" ]; then
        log_error "应用目录不存在: $app_path"
        return 1
    fi

    if [ ! -f "$app_path/artisan" ]; then
        log_error "artisan 文件不存在: $app_path/artisan"
        return 1
    fi

    log_info "应用目录检查通过: $app_path"
    return 0
}

# 主健康检查函数
main_health_check() {
    local exit_code=0

    log_info "开始健康检查..."
    log_info "ENABLE_SUPERVISOR=${ENABLE_SUPERVISOR:-false}"

    # 检查应用目录
    if ! check_app_directory; then
        exit_code=1
    fi

    # 检查 Supervisor 进程（根据环境变量决定）
    if ! check_supervisor_process; then
        exit_code=1
    fi

    # 检查 HTTP 服务
    if ! check_http_service; then
        exit_code=1
    fi

    if [ $exit_code -eq 0 ]; then
        log_info "健康检查通过"
    else
        log_error "健康检查失败"
    fi

    return $exit_code
}

main_health_check
