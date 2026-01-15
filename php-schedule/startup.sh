#!/bin/bash

# Laravel Schedule 启动脚本
# 使用 supervisor 管理定时任务进程

set -e

# 健康检查函数 - 检测 supercronic 进程是否运行
health_check() {
    # 检查 supercronic 进程是否在运行
    if pgrep -f "supercronic.*laravel-cron" > /dev/null; then
        return 0
    else
        return 1
    fi
}

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

# 生成 laravel-cron 文件
generate_cron_file() {
    local cron_file="/usr/local/etc/laravel-cron"

    # 确保目录存在
    mkdir -p /usr/local/etc

    log_info "生成 Laravel cron 配置文件..."

    cat > "${cron_file}" << EOF
# 每分钟执行调度器
* * * * * /usr/local/bin/php ${APP_PATH}/artisan schedule:run --env=${APP_ENV}

# 每天凌晨清理调度器缓存（每天0点执行）
0 0 * * * /usr/local/bin/php ${APP_PATH}/artisan schedule:clear-cache --env=${APP_ENV}
EOF

    chmod +x "${cron_file}"
    log_success "已生成 cron 配置文件: ${cron_file}"
    log_info "配置详情: APP_PATH=${APP_PATH}"
}

# 动态生成 supervisor 配置文件
generate_supervisor_config() {
    local config_dir="/usr/local/etc/supervisord.d"
    local scheduler_config="${config_dir}/scheduler.conf"

    # 确保目录存在
    mkdir -p "$config_dir"

    log_info "生成 supervisor scheduler 配置文件..."

    # 创建 scheduler.conf 配置文件
    cat > "${scheduler_config}" << EOF
[program:scheduler]
environment=APP_ENV="${APP_ENV}",APP_DEBUG="false",APP_PATH="${APP_PATH}"
process_name = %(program_name)s_%(process_num)s
command = supercronic -overlapping /usr/local/etc/laravel-cron
autostart = true
autorestart = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
EOF

    log_success "已生成 supervisor scheduler 配置文件: ${scheduler_config}"
    log_info "配置详情: APP_PATH=${APP_PATH}, APP_ENV=${APP_ENV}"
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
    log_info "=== Laravel Schedule 启动配置 ==="
    log_info "应用路径: ${APP_PATH}"
    log_info "运行环境: ${APP_ENV}"
    log_info "启用 Supervisor: ${ENABLE_SUPERVISOR}"
    log_info "=================================="
}

# 启动 supervisor
start_supervisor() {
    log_info "启动 supervisor 管理定时任务进程..."

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

# 直接运行定时任务（不使用 supervisor）
start_direct() {
    log_info "启动 supercronic 执行定时任务..."
    log_info "执行命令: supercronic -overlapping /usr/local/etc/laravel-cron"
    exec /usr/local/bin/supercronic -overlapping /usr/local/etc/laravel-cron
}

# 主函数
main() {
    log_info "启动 Laravel Schedule 服务..."
     # 生成 cron 配置文件
    generate_cron_file
    # 显示配置
    show_config
    # 检查应用目录
    check_app_directory
    # 检查是否启用 supervisor
    if [ "${ENABLE_SUPERVISOR}" = "true" ]; then
        start_supervisor
    else
        start_direct
    fi
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止服务..."; exit 0' SIGTERM SIGINT

# 健康检查入口点
if [ "$1" = "healthcheck" ]; then
    if health_check; then
        echo "supercronic is running"
        exit 0
    else
        echo "supercronic is not running"
        exit 1
    fi
fi

# 运行主函数
main "$@"
