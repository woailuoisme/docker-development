#!/bin/bash

# Laravel Octane with RoadRunner 健康检查脚本
set -e

# 日志工具
RED='\033[0;31m' GREEN='\033[0;32m' NC='\033[0m'
log() { echo -e "${1}[$(date '+%Y-%m-%d %H:%M:%S %z')] [HEALTH]${NC} ${2}" >&2; }
log_info() { log "${GREEN}" "$1"; }
log_err()  { log "${RED}" "$1"; }

# 1. 检查应用目录
[ -f "${APP_PATH:-/var/www/lunchbox}/artisan" ] || { log_err "应用目录或 artisan 不存在"; exit 1; }

# 2. 检查进程 (通过 /proc 检查，避开自身)
check_process() {
    for pid_dir in /proc/[0-9]*/; do
        [ "$pid_dir" = "/proc/$$/" ] && continue
        # 匹配 octane:start 或 rr serve
        if (grep -qa "octane" "${pid_dir}cmdline" 2>/dev/null && grep -qa "start" "${pid_dir}cmdline" 2>/dev/null) || \
           (grep -qa "rr" "${pid_dir}cmdline" 2>/dev/null && grep -qa "serve" "${pid_dir}cmdline" 2>/dev/null); then
            return 0
        fi
    done
    return 1
}

if ! check_process; then
    log_err "RoadRunner/Octane 进程异常"
    exit 1
fi

# 3. 检查 HTTP 响应
if curl -f -s -m 5 "http://localhost:${APP_PORT:-8001}/api/live" > /dev/null 2>&1; then
    log_info "RoadRunner/HTTP 服务正常"
    exit 0
else
    log_err "HTTP 服务无响应"
    exit 1
fi
