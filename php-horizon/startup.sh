#!/bin/bash

# Laravel Horizon 启动脚本
# 直接运行 php artisan horizon 命令

# 健康检查函数 - 检测 Horizon 进程是否运行
health_check() {
    if [ "${ENABLE_SUPERVISOR}" = "true" ]; then
        # Supervisor 模式下的健康检查
        if supervisorctl status horizon | grep -q "RUNNING"; then
            return 0
        else
            return 1
        fi
    else
        # 直接启动模式下的健康检查
        if pgrep -f "php.*artisan.*horizon" > /dev/null; then
            return 0
        else
            return 1
        fi
    fi
}

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
readonly ENABLE_SUPERVISOR=${ENABLE_SUPERVISOR:-false}

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

# 检查 Horizon 配置
check_horizon_config() {
    log_info "检查 Laravel Horizon 配置..."

    # 检查 horizon 配置文件
    if [ ! -f "${APP_PATH}/config/horizon.php" ]; then
        log_warning "Horizon 配置文件不存在，将使用默认配置"
    else
        log_success "Horizon 配置文件存在"
    fi

    # 检查是否安装了 horizon
    if [ ! -d "${APP_PATH}/vendor/laravel/horizon" ]; then
        log_error "Horizon 包未安装，请运行: composer require laravel/horizon"
        exit 1
    fi
    log_success "Horizon 包已安装"

    # 检查 artisan 命令是否可用
    if ! php "${APP_PATH}/artisan" --version > /dev/null 2>&1; then
        log_error "artisan 命令不可用"
        exit 1
    fi
    log_success "artisan 命令可用"

    log_success "Laravel Horizon 配置检查通过"
}

# 动态生成 supervisor 配置文件
generate_supervisor_config() {
    local config_dir="/usr/local/etc/supervisord.d"
    local horizon_config="${config_dir}/horizon.conf"

    # 确保目录存在
    mkdir -p "$config_dir"

    log_info "生成 supervisor horizon 配置文件..."

    # 创建 horizon.conf 配置文件
    cat > "${horizon_config}" << EOF
[program:horizon]
environment=APP_ENV="${APP_ENV}",APP_DEBUG="false",APP_PATH="${APP_PATH}"
process_name = %(program_name)s_%(process_num)s
command = php ${APP_PATH}/artisan horizon --environment=${APP_ENV} --env=${APP_ENV}
autostart = true
autorestart = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
EOF

    log_success "已生成 supervisor horizon 配置文件: ${horizon_config}"
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
    log_info "=== Laravel Horizon 启动配置 ==="
    log_info "应用路径: ${APP_PATH}"
    log_info "运行环境: ${APP_ENV}"
    log_info "Supervisor 模式: ${ENABLE_SUPERVISOR}"
    if [ "${ENABLE_SUPERVISOR}" = "true" ]; then
        log_info "启动命令: supervisorctl start horizon"
    else
        log_info "启动命令: php ${APP_PATH}/artisan horizon --environment=${APP_ENV} --env=${APP_ENV}"
    fi
    log_info "=================================="
}

# 启动 Laravel Horizon
start_horizon() {
    log_info "启动 Laravel Horizon..."

    cd "${APP_PATH}"
    log_info "切换到应用目录: $(pwd)"

    if [ "${ENABLE_SUPERVISOR}" = "true" ]; then
        log_info "Supervisor 模式已启用"

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

        log_info "执行命令: supervisorctl start horizon"
        log_info "Horizon 将由 Supervisor 管理"
        exec supervisord -n -c /usr/local/etc/supervisord.conf
    else
        log_info "直接启动模式"
        log_info "执行命令: php ${APP_PATH}/artisan horizon --environment=${APP_ENV} --env=${APP_ENV}"
        log_info "Horizon 将在前台运行，按 Ctrl+C 停止"
        exec php "${APP_PATH}/artisan" horizon --environment="${APP_ENV}" --env="${APP_ENV}"
    fi
}

# 健康检查入口点
if [ "$1" = "healthcheck" ]; then
    if health_check; then
        echo "Horizon is running"
        exit 0
    else
        echo "Horizon is not running"
        exit 1
    fi
fi

# 主函数
main() {
    log_info "启动 Laravel Horizon 服务..."

    # 显示配置
    show_config

    # 检查应用目录
    check_app_directory

    # 检查 Horizon 配置
    check_horizon_config

    # 启动 Horizon
    start_horizon
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止 Horizon..."; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
