#!/usr/bin/env bash
set -euo pipefail

# 全局变量
readonly WWWUSER=${WWWUSER:-33}
readonly WWWGROUP=${WWWGROUP:-33}
readonly ENABLE_SUPERVISOR=${ENABLE_SUPERVISOR:-true}
readonly ENABLE_REVERB=${ENABLE_REVERB:-true}
readonly ENABLE_SCHEDULE=${ENABLE_SCHEDULE:-true}
readonly ENABLE_HORIZON=${ENABLE_HORIZON:-true}
readonly ENABLE_WORKER=${ENABLE_WORKER:-true}
readonly ENABLE_PULSE=${ENABLE_PULSE:-true}
readonly APP_PATH=${APP_PATH:-/var/www/lunchbox}
readonly APP_ENV=${APP_ENV:-docker}

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

log() {
    echo -e "[$(date '+%H:%M:%S')] $*" >&2
}

log_info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO: $*${NC}" >&2
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] SUCCESS: $*${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $*${NC}" >&2
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $*${NC}" >&2
}

log_debug() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] DEBUG: $*${NC}" >&2
}
# 用户切换执行函数
exec_as_user() {
    if [ "$(id -u)" = "0" ]; then
        exec "$@"
    else
        exec gosu www-data "$@"
    fi
}

# 安全执行函数，避免ptrace问题
safe_exec() {
    # 使用exec -c来清除环境变量，减少潜在冲突
    if [ "$(id -u)" = "0" ]; then
        exec -c "$@"
    else
        exec -c gosu www-data "$@"
    fi
}

# 检查依赖和设置权限
setup_environment() {
    # 检查依赖
    command -v gosu >/dev/null || { log_error "gosu not found"; exit 1; }

    # 确保用户和组ID一致性
    ensure_user_consistency

    # 确保错误日志文件存在（Dockerfile已创建目录并设置权限）
        if [ "$(id -u)" = "0" ]; then
            local log_files=(/var/log/php-fpm/error.log /var/log/php-fpm/slow.log)

            for file in "${log_files[@]}"; do
                touch "$file" 2>/dev/null || true
                chown www-data:www-data "$file" 2>/dev/null || true
                chmod 666 "$file" 2>/dev/null || true
            done
        fi

        # 确保SSH目录权限正确（如果挂载了SSH密钥）
        if [ -d "/home/www-data/.ssh" ]; then
            log_info "设置SSH目录权限..."
            chown -R www-data:www-data /home/www-data/.ssh 2>/dev/null || true
            chmod 700 /home/www-data/.ssh 2>/dev/null || true

            # 设置所有SSH文件的正确权限
            if [ -f "/home/www-data/.ssh/known_hosts" ]; then
                chown www-data:www-data /home/www-data/.ssh/known_hosts 2>/dev/null || true
                chmod 644 /home/www-data/.ssh/known_hosts 2>/dev/null || true
            fi
            if [ -f "/home/www-data/.ssh/id_ed25519" ]; then
                chown www-data:www-data /home/www-data/.ssh/id_ed25519 2>/dev/null || true
                chmod 600 /home/www-data/.ssh/id_ed25519 2>/dev/null || true
            fi
            if [ -f "/home/www-data/.ssh/id_ed25519.pub" ]; then
                chown www-data:www-data /home/www-data/.ssh/id_ed25519.pub 2>/dev/null || true
                chmod 644 /home/www-data/.ssh/id_ed25519.pub 2>/dev/null || true
            fi
            if [ -f "/home/www-data/.ssh/config" ]; then
                chown www-data:www-data /home/www-data/.ssh/config 2>/dev/null || true
                chmod 600 /home/www-data/.ssh/config 2>/dev/null || true
            fi
        fi

    log_success "环境设置完成"
}

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
    local scheduler_config="${config_dir}/scheduler.conf"
    local worker_config="${config_dir}/worker.conf"
    local reverb_config="${config_dir}/reverb.conf"
    local horizon_config="${config_dir}/horizon.conf"

    log_info "生成 supervisor 配置文件..."

    # 清理旧的配置文件
    rm -f "${config_dir}"/*.conf

    # 显示当前配置目录内容
    log_debug "配置目录: ${config_dir}"
    if [ -d "${config_dir}" ]; then
        log_debug "配置目录内容: $(ls -la "${config_dir}" 2>/dev/null || echo "empty or not accessible")"
    fi

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

    # 只有在启用工作器时才生成worker配置
    if [ "$ENABLE_WORKER" = "true" ]; then
        cat > "${worker_config}" << EOF
[program:worker]
environment=APP_ENV="${APP_ENV}",APP_DEBUG="false",APP_PATH="${APP_PATH}"
process_name = %(program_name)s_%(process_num)s
command = /usr/local/bin/php ${APP_PATH}/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart = true
autorestart = true
numprocs = 2
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
stderr_logfile = /dev/stderr
stderr_logfile_maxbytes = 0
EOF
        log_success "已生成 worker 配置文件"
    else
        log_warning "工作器未启用，跳过生成 worker 配置"
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

    log_success "supervisor 配置文件生成完成"

    # 显示生成的配置文件
    if [ -d "${config_dir}" ]; then
        local generated_files=$(find "${config_dir}" -name "*.conf" 2>/dev/null | wc -l)
        log_info "已生成 $generated_files 个 supervisor 配置文件"
        if [ "$generated_files" -gt 0 ]; then
            log_debug "生成的配置文件: $(find "${config_dir}" -name "*.conf" -exec basename {} \; 2>/dev/null | tr '\n' ' ')"
        fi
    fi
}

# 确保用户和组ID一致性
ensure_user_consistency() {
    # 检查用户是否存在
    if id -u www-data >/dev/null 2>&1; then
        # 检查现有用户的UID/GID是否匹配环境变量
        local current_uid=$(id -u www-data)
        local current_gid=$(id -g www-data)

        if [ "$current_uid" != "$WWWUSER" ] || [ "$current_gid" != "$WWWGROUP" ]; then
            log_warning "www-data 用户ID不匹配 (当前: UID=$current_uid GID=$current_gid, 期望: UID=$WWWUSER GID=$WWWGROUP)"
            log_warning "删除现有用户并重新创建以匹配配置..."

            # 删除现有用户和组
            deluser www-data 2>/dev/null || true
            delgroup www-data 2>/dev/null || true

            # 创建新的用户和组 (Alpine Linux 参数格式)
            addgroup -g "$WWWGROUP" www-data 2>/dev/null || true
            adduser -u "$WWWUSER" -D -H -G www-data www-data 2>/dev/null || true

            # 验证用户创建是否成功
            if id -u www-data >/dev/null 2>&1; then
                local new_uid=$(id -u www-data)
                local new_gid=$(id -g www-data)
                log_success "已重新创建 www-data 用户 (UID: $new_uid, GID: $new_gid)"
            else
                log_error "无法创建 www-data 用户"
                exit 1
            fi
        else
            log_success "www-data 用户ID匹配 (UID: $current_uid, GID: $current_gid)"
        fi
    else
        # 用户不存在，直接创建
        log_info "创建 www-data 用户 (UID: $WWWUSER, GID: $WWWGROUP)"
        addgroup -g "$WWWGROUP" www-data 2>/dev/null || true
        adduser -u "$WWWUSER" -D -H -G www-data www-data 2>/dev/null || true

        # 验证用户创建是否成功
        if ! id -u www-data >/dev/null 2>&1; then
            log_error "无法创建 www-data 用户"
            exit 1
        fi
    fi
}

# 验证配置文件
validate_configs() {
    log_info "开始验证配置..."

    # 验证 PHP-FPM 配置
    if ! php-fpm -t >/dev/null 2>&1; then
        log_error "PHP-FPM 配置无效"
        php-fpm -t
        exit 1
    fi

    log_success "配置验证完成"
}
# 优雅关闭
graceful_shutdown() {
    log_info "正在关闭..."
    pkill -TERM php-fpm 2>/dev/null || true
    exit 0
}

# 启动 PHP-FPM
start_php_fpm() {
    log_info "启动 PHP-FPM..."
    # 如果以root用户运行，使用gosu切换到www-data用户启动PHP-FPM
    if [ "$(id -u)" = "0" ]; then
        safe_exec php-fpm --nodaemonize
    else
        # 非root用户运行时，直接启动PHP-FPM（已经是www-data用户）
        php-fpm --nodaemonize
    fi
}

# 启动 supervisord（后台进程）
start_supervisord_background() {
    log_info "启动 supervisord（后台模式）..."

    # 如果以root用户运行，使用gosu切换到www-data用户启动supervisord
    if [ "$(id -u)" = "0" ]; then
        gosu www-data supervisord -c /usr/local/etc/supervisord.conf &
    else
        # 非root用户运行时，直接启动supervisord（已经是www-data用户）
        supervisord -c /usr/local/etc/supervisord.conf &
    fi

    local supervisord_pid=$!

    # 等待supervisord启动完成
    sleep 3

    # 检查supervisord是否正常运行
    if kill -0 "$supervisord_pid" 2>/dev/null; then
        log_success "supervisord 启动成功，PID: $supervisord_pid"

        # 检查supervisord进程状态
        sleep 2
        if supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 status >/dev/null 2>&1; then
            log_success "supervisord 进程管理正常"
            supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 status
        else
            log_warning "supervisord 进程管理连接失败"
        fi

        return 0
    else
        log_error "supervisord 启动失败"
        return 1
    fi
}

## 切换到 www-data 用户（或容器内实际使用的用户）
#USER www-data
#
## 创建 .ssh 目录并添加 GitHub 主机指纹
#RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
#    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
#    chmod 644 ~/.ssh/known_hosts

# 检查是否有supervisord配置
has_supervisord_config() {
    # 检查是否有supervisord配置文件
    if [ -f "/usr/local/etc/supervisord.conf" ] && [ -d "/usr/local/etc/supervisord.d" ]; then
        # 重新扫描配置文件目录
        local config_count=$(find /usr/local/etc/supervisord.d -name "*.conf" 2>/dev/null | wc -l)
        if [ "$config_count" -gt 0 ]; then
            log_info "检测到 $config_count 个 supervisor 配置文件"
            return 0
        fi
    fi
    log_warning "未检测到 supervisor 配置文件"
    return 1
}

# 主函数
main() {
    log_info "容器启动中..."
    trap 'graceful_shutdown' TERM INT QUIT

    setup_environment
    validate_configs

    # 处理命令行参数
    if [ $# -gt 0 ]; then
        log_info "执行自定义命令: $*"
        safe_exec "$@"
    fi

    # 检查是否有supervisord配置，如果ENABLE_SUPERVISOR为true则启动supervisord
    if [ "$ENABLE_SUPERVISOR" = "true" ]; then
        log_info "启用 supervisor 管理后台进程..."

        # 生成必要的配置文件
        generate_cron_file
        generate_supervisor_config

        # 检查是否生成了任何配置文件
        local config_count=$(find /usr/local/etc/supervisord.d -name "*.conf" 2>/dev/null | wc -l)
        if [ "$config_count" -gt 0 ]; then
            log_success "已生成 $config_count 个 supervisor 配置文件，启动 supervisord..."
            start_supervisord_background
        else
            log_warning "没有生成任何 supervisor 配置文件，跳过启动 supervisor"
        fi
    fi

    # 前台启动 PHP-FPM（主进程）
    log_info "启动PHP-FPM服务..."
    start_php_fpm
}

main "$@"
