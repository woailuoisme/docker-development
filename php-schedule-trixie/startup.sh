#!/bin/bash

# Laravel Schedule 启动脚本
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

# 2. 生成 cron 配置
generate_cron_file() {
    local cron_file="/usr/local/etc/laravel-cron"
    log_info "生成 Laravel cron 配置文件..."
    cat > "${cron_file}" << EOF
# 每分钟执行调度器
* * * * * /usr/local/bin/php ${APP_PATH}/artisan schedule:run --env=${APP_ENV}
# 每天凌晨清理缓存
0 0 * * * /usr/local/bin/php ${APP_PATH}/artisan schedule:clear-cache --env=${APP_ENV}
EOF
    log_success "已生成: ${cron_file}"
}

# 3. 健康检查
health_check() {
    # 遍历进程目录，避开当前脚本进程
    for pid_dir in /proc/[0-9]*/; do
        [ "$pid_dir" = "/proc/$$/" ] && continue
        if grep -qa "supercronic" "${pid_dir}cmdline" 2>/dev/null && \
           grep -qa "laravel-cron" "${pid_dir}cmdline" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

if [ "$1" = "healthcheck" ]; then
    health_check && exit 0 || exit 1
fi

# 4. 主流程
log_info "启动 Laravel Schedule 服务..."
generate_cron_file
check_app_directory
log_info "启动 supercronic..."
exec /usr/local/bin/supercronic -overlapping /usr/local/etc/laravel-cron
