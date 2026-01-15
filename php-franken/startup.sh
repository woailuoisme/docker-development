#!/bin/bash

# Laravel Octane with FrankenPHP 启动脚本
# FrankenPHP 前台启动，supervisor 后台启动管理其他进程

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
readonly ENABLE_SUPERVISOR=${ENABLE_SUPERVISOR:-true}
readonly ENABLE_REVERB=${ENABLE_REVERB:-true}
readonly ENABLE_SCHEDULE=${ENABLE_SCHEDULE:-true}
readonly ENABLE_HORIZON=${ENABLE_HORIZON:-true}
readonly ENABLE_PULSE=${ENABLE_PULSE:-true}

# 生成 laravel-cron 文件
generate_cron_file() {
    local cron_file="/tmp/laravel-cron"

    log_info "生成 Laravel cron 配置文件..."

    # 只有在启用调度器时才生成cron配置
    if [ "$ENABLE_SCHEDULE" = "true" ]; then
        cat > "${cron_file}" << EOF
# 每分钟执行调度器
* * * * * /usr/local/bin/php ${APP_PATH}/artisan schedule:run

# 每天凌晨清理调度器缓存（每天0点执行）
0 0 * * * /usr/local/bin/php ${APP_PATH}/artisan schedule:clear-cache
EOF

#        chmod 644 "${cron_file}"
        log_success "已生成 cron 配置文件: ${cron_file}"
    else
        log_warning "调度器未启用，跳过生成 cron 配置"
        # 如果文件存在但调度器被禁用，则删除文件
        if [ -f "${cron_file}" ]; then
            rm -f "${cron_file}"
        fi
    fi
}

# 动态生成 supervisor 配置文件
generate_supervisor_config() {
    local config_dir="/usr/local/etc/supervisord.d"
    local pulse_config="${config_dir}/pulse.check.conf"
    local reverb_config="${config_dir}/reverb.conf"
    local scheduler_config="${config_dir}/scheduler.conf"
    local horizon_config="${config_dir}/horizon.conf"

    log_info "生成 supervisor 配置文件..."

    # 清理旧的配置文件
    rm -f "${config_dir}"/*.conf

    # 只有在启用Pulse时才生成pulse配置
    if [ "$ENABLE_PULSE" = "true" ]; then
        cat > "${pulse_config}" << EOF
[program:pulse]
environment=APP_ENV="${APP_ENV}",APP_DEBUG="false",APP_PATH="${APP_PATH}"
process_name = %(program_name)s_%(process_num)s
command = /usr/local/bin/php ${APP_PATH}/artisan pulse:check
autostart = true
autorestart = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
EOF
        log_success "已生成 pulse 配置文件"
    else
        log_warning "Pulse 未启用，跳过生成 pulse 配置"
    fi

    # 只有在启用Reverb时才生成reverb配置
    if [ "$ENABLE_REVERB" = "true" ]; then
        cat > "${reverb_config}" << EOF
[program:reverb]
environment=APP_ENV="${APP_ENV}",APP_DEBUG="false",APP_PATH="${APP_PATH}"
process_name = %(program_name)s_%(process_num)s
command = /usr/local/bin/php ${APP_PATH}/artisan reverb:start --host=0.0.0.0 --port=8080
autostart = true
autorestart = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
EOF
        log_success "已生成 reverb 配置文件"
    else
        log_warning "Reverb 未启用，跳过生成 reverb 配置"
    fi

    # 只有在启用调度器时才生成scheduler配置
    if [ "$ENABLE_SCHEDULE" = "true" ]; then
        cat > "${scheduler_config}" << EOF
[program:scheduler]
environment=APP_ENV="${APP_ENV}",APP_DEBUG="false",APP_PATH="${APP_PATH}"
process_name = %(program_name)s_%(process_num)s
command = supercronic -overlapping /tmp/laravel-cron
autostart = true
autorestart = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
EOF
        log_success "已生成 scheduler 配置文件"
    else
        log_warning "调度器未启用，跳过生成 scheduler 配置"
    fi

    # 只有在启用Horizon时才生成horizon配置
    if [ "$ENABLE_HORIZON" = "true" ]; then
        cat > "${horizon_config}" << EOF
[program:horizon]
environment=APP_ENV="${APP_ENV}",APP_DEBUG="false",APP_PATH="${APP_PATH}"
process_name = %(program_name)s_%(process_num)s
command = /usr/local/bin/php ${APP_PATH}/artisan horizon
autostart = true
autorestart = true
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
EOF
        log_success "已生成 horizon 配置文件"
    else
        log_warning "Horizon 未启用，跳过生成 horizon 配置"
    fi

    # 显示生成的进程配置
    local config_count=$(find "${config_dir}" -name "*.conf" 2>/dev/null | wc -l)
    log_success "已生成 ${config_count} 个 supervisor 配置文件"
    log_info "后台进程配置: $([ "$ENABLE_PULSE" = "true" ] && echo "pulse")$([ "$ENABLE_REVERB" = "true" ] && echo ", reverb")$([ "$ENABLE_SCHEDULE" = "true" ] && echo ", scheduler")$([ "$ENABLE_HORIZON" = "true" ] && echo ", horizon")"
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
    log_info "=== Laravel Octane 启动配置 ==="
    log_info "应用路径: ${APP_PATH}"
    log_info "运行环境: ${APP_ENV}"
    log_info "启用 Supervisor: ${ENABLE_SUPERVISOR}"
    log_info "启用 Reverb: ${ENABLE_REVERB}"
    log_info "启用 Schedule: ${ENABLE_SCHEDULE}"
    log_info "启用 Horizon: ${ENABLE_HORIZON}"
    log_info "启用 Pulse: ${ENABLE_PULSE}"
    log_info "服务器: frankenphp"
    log_info "端口: ${APP_PORT}"
    log_info "监听地址: ${OCTANE_HOST}"
    log_info "工作进程数: ${OCTANE_WORKERS}"
    log_info "管理端口: ${OCTANE_ADMIN_PORT}"
    log_info "最大请求数: ${OCTANE_MAX_REQUESTS}"
    log_info "文件监听: ${WATCH}"
    log_info "网络轮询: ${OCTANE_POLL}"
    log_info "HTTPS: ${OCTANE_HTTPS}"
    log_info "HTTP重定向: ${OCTANE_HTTP_REDIRECT}"
    if [ "${ENABLE_OCTANE_LOG_LEVEL}" != "false" ]; then
        log_info "日志级别: ${OCTANE_LOG_LEVEL}"
    else
        log_info "日志级别: 已禁用"
    fi
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

# 启动 supervisor（后台模式）
start_supervisor_background() {
    log_info "启动 supervisor 管理后台进程..."

    # 生成必要的配置文件
    generate_cron_file
    generate_supervisor_config

    # 检查 supervisor 配置
    if ! check_supervisor_config; then
        log_error "supervisor 配置检查失败，无法启动"
        return 1
    fi

    # 显示 supervisor 配置信息
    log_info "supervisord 配置文件: /usr/local/etc/supervisord.conf"
    log_info "进程配置文件目录: /usr/local/etc/supervisord.d/"

    # 显示进程配置
    local config_files=$(find /usr/local/etc/supervisord.d -name "*.conf" 2>/dev/null)
    for config_file in $config_files; do
        log_info "加载后台进程配置: $(basename $config_file)"
        # 显示进程配置详情
        if grep -q "^\[program:" "$config_file"; then
            local program_name=$(grep "^\[program:" "$config_file" | sed 's/\[program://;s/\]//')
            local command=$(grep "^command\s*=" "$config_file" | head -1 | sed 's/command\s*=\s*//')
            log_info "  - 进程: ${program_name}"
            log_info "  - 命令: ${command}"
        fi
    done

    # 在后台启动 supervisor
    log_info "在后台模式启动 supervisord..."
    supervisord -c /usr/local/etc/supervisord.conf &
    local supervisor_pid=$!

    # 等待supervisord启动完成
    sleep 3

    # 检查supervisord是否正常运行
    if kill -0 "$supervisor_pid" 2>/dev/null; then
        log_success "supervisord 启动成功，PID: $supervisor_pid"

        # 检查supervisord进程状态
        sleep 2
        if supervisorctl -c /usr/local/etc/supervisord.conf status >/dev/null 2>&1; then
            log_success "supervisord 进程管理正常"
            supervisorctl -c /usr/local/etc/supervisord.conf status
        else
            log_warning "supervisord 进程管理连接失败"
        fi
    else
        log_error "supervisord 启动失败"
        return 1
    fi
}

# 前台启动 FrankenPHP
start_frankenphp_foreground() {
    log_info "前台启动 FrankenPHP..."
    build_start_command_display

    # 前台启动 FrankenPHP（主进程）
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

# 构建启动命令字符串（仅用于显示）
build_start_command_display() {
    local command="php artisan octane:frankenphp"

    # 基本参数
    command="${command} --port=${APP_PORT}"
    command="${command} --host=${OCTANE_HOST}"
    command="${command} --workers=${OCTANE_WORKERS}"
    command="${command} --admin-port=${OCTANE_ADMIN_PORT}"
    command="${command} --max-requests=${OCTANE_MAX_REQUESTS}"
    command="${command} --env=${APP_ENV}"
    
    # 条件参数：日志级别
    if [ "${ENABLE_OCTANE_LOG_LEVEL}" != "false" ]; then
        command="${command} --log-level=${OCTANE_LOG_LEVEL}"
        log_info "日志级别: ${OCTANE_LOG_LEVEL}"
    else
        log_info "日志级别参数已禁用"
    fi

    # 条件参数
    if [ "${WATCH}" = "true" ]; then
        command="${command} --watch"
        log_info "启用文件监听模式"
    fi

    if [ "${OCTANE_POLL}" = "true" ]; then
        command="${command} --poll"
        log_info "启用网络文件轮询模式"
    fi

    if [ "${OCTANE_HTTPS}" = "true" ]; then
        command="${command} --https"
        log_info "启用 HTTPS/HTTP2/HTTP3"
    fi

    if [ "${OCTANE_HTTP_REDIRECT}" = "true" ]; then
        command="${command} --http-redirect"
        log_info "启用 HTTP 到 HTTPS 重定向"
    fi

    log_info "前台进程命令: ${command}"
}

# 主函数
main() {
    log_info "启动 Laravel Octane with FrankenPHP..."

    # 显示配置
    show_config

    # 检查应用目录
    check_app_directory

    # 切换到应用目录
    cd "${APP_PATH}"
    log_info "切换到应用目录: $(pwd)"

    # 检查是否启用 supervisor
    if [ "${ENABLE_SUPERVISOR}" = "true" ]; then
        # 启动 supervisor 后台进程
        if start_supervisor_background; then
            log_success "后台进程管理已启动"
        else
            log_warning "后台进程管理启动失败，继续启动 FrankenPHP"
        fi
    else
        log_warning "Supervisor 未启用，只启动 FrankenPHP"
    fi

    # 前台启动 FrankenPHP（主进程）
    start_frankenphp_foreground
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止服务..."; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
