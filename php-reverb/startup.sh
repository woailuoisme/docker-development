#!/bin/bash

# Laravel Reverb 启动脚本
# 使用 supervisor 管理 WebSocket 服务器进程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${BLUE}[${timestamp}] [INFO]${NC} $1"
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${GREEN}[${timestamp}] [SUCCESS]${NC} $1"
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${YELLOW}[${timestamp}] [WARNING]${NC} $1"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${RED}[${timestamp}] [ERROR]${NC} $1"
}

# 全局变量
readonly APP_PATH=${APP_PATH:-/var/www/lunchbox}
readonly APP_ENV=${APP_ENV:-docker}
readonly REVERB_DEBUG=${REVERB_DEBUG:-true}
readonly ENABLE_SUPERVISOR=${ENABLE_SUPERVISOR:-true}

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

# 动态生成 supervisor 配置文件
generate_supervisor_config() {
    local config_dir="/usr/local/etc/supervisord.d"
    local reverb_config="${config_dir}/reverb.conf"

    log_info "生成 supervisor reverb 配置文件..."

    # 构建命令
    local reverb_command
    if [ "${REVERB_DEBUG}" = "true" ]; then
        reverb_command="/usr/local/bin/php ${APP_PATH}/artisan reverb:start --debug"
    else
        reverb_command="/usr/local/bin/php ${APP_PATH}/artisan reverb:start"
    fi

    # 创建 reverb.conf 配置文件
    cat > "${reverb_config}" << EOF
[program:reverb]
environment=APP_ENV="${APP_ENV}",APP_DEBUG="false",APP_PATH="${APP_PATH}",REVERB_DEBUG="${REVERB_DEBUG}"
process_name = %(program_name)s_%(process_num)s
command = ${reverb_command}
autostart = true
autorestart = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
minfds = 10000
EOF

    log_success "已生成 supervisor reverb 配置文件: ${reverb_config}"
    log_info "配置详情: APP_PATH=${APP_PATH}, APP_ENV=${APP_ENV}, REVERB_DEBUG=${REVERB_DEBUG}"
}

# 检查 supervisor 配置
check_supervisor_config() {
    if [ ! -f "/usr/local/etc/supervisord.conf" ]; then
        log_error "supervisord 主配置文件不存在: /usr/local/etc/supervisord.conf"
        return 1
    fi

    if [ ! -d "/usr/local/etc/supervisord.d" ]; then
        log_error "supervisord 配置目录不存在: /usr/local/etc/supervisord.d"
        return 1
    fi

    local config_count=$(find /usr/local/etc/supervisord.d -name "*.conf" 2>/dev/null | wc -l)
    if [ "$config_count" -eq 0 ]; then
        log_warning "未找到任何 supervisord 进程配置文件"
        return 1
    fi

    log_success "supervisor 配置检查通过，找到 ${config_count} 个进程配置"
    return 0
}

# 显示启动配置
show_config() {
    log_info "=== Laravel Reverb 启动配置 ==="
    log_info "应用路径: ${APP_PATH}"
    log_info "运行环境: ${APP_ENV}"
    log_info "启用 Supervisor: ${ENABLE_SUPERVISOR}"
    log_info "启用调试模式: ${REVERB_DEBUG}"
    log_info "=================================="
}

# 启动 supervisor
start_supervisor() {
    log_info "启动 supervisor 管理 Reverb WebSocket 服务器..."

    # 动态生成 supervisor 配置文件
    generate_supervisor_config

    # 检查 supervisor 配置
    if ! check_supervisor_config; then
        log_error "supervisor 配置检查失败，无法启动"
        exit 1
    fi

    # 显示 supervisor 配置信息
    log_info "supervisord 配置文件: /usr/local/etc/supervisord.conf"
    log_info "进程配置文件目录: /usr/local/etc/supervisord.d/"

    # 显示进程配置
    local config_files=$(find /usr/local/etc/supervisord.d -name "*.conf" 2>/dev/null)
    for config_file in $config_files; do
        log_info "加载进程配置: $(basename $config_file)"
        # 显示进程配置详情
        if grep -q "^\[program:" "$config_file"; then
            local program_name=$(grep "^\[program:" "$config_file" | sed 's/\[program://;s/\]//')
            local command=$(grep "^command\s*=" "$config_file" | head -1 | sed 's/command\s*=\s*//')
            log_info "  - 进程: ${program_name}"
            log_info "  - 命令: ${command}"
        fi
    done

    # 在前台启动 supervisor
    log_info "在前台模式启动 supervisord..."
    exec supervisord -c /usr/local/etc/supervisord.conf -n
}

# 直接运行 Reverb（不使用 supervisor）
start_direct() {
    log_warning "Supervisor 未启用，将直接运行 Reverb WebSocket 服务器"

    # 构建命令
    local reverb_command
    if [ "${REVERB_DEBUG}" = "true" ]; then
        reverb_command="php ${APP_PATH}/artisan reverb:start --debug"
    else
        reverb_command="php ${APP_PATH}/artisan reverb:start"
    fi

    log_info "执行命令: ${reverb_command}"
    exec ${reverb_command}
}

# 主函数
main() {
    log_info "启动 Laravel Reverb WebSocket 服务器..."

    # 显示配置
    show_config

    # 检查应用目录
    check_app_directory

    # 切换到应用目录
    cd "${APP_PATH}"
    log_info "切换到应用目录: $(pwd)"

    # 检查是否启用 supervisor
    if [ "${ENABLE_SUPERVISOR}" = "true" ]; then
        start_supervisor
    else
        start_direct
    fi
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止服务..."; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
