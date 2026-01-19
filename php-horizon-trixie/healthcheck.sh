#!/bin/bash

# Laravel Horizon 健康检查脚本
set -e

# 日志工具
RED='\033[0;31m' GREEN='\033[0;32m' NC='\033[0m'
log() { echo -e "${1}[$(date '+%Y-%m-%d %H:%M:%S %z')] [HEALTH]${NC} ${2}" >&2; }
log_info() { log "${GREEN}" "$1"; }
log_err()  { log "${RED}" "$1"; }

# 1. 检查应用目录
[ -d "${APP_PATH:-/var/www/lunchbox}" ] || { log_err "应用目录不存在"; exit 1; }

# 2. 检查进程 (通过 /proc 检查，避开自身)
check_process() {
    for pid_dir in /proc/[0-9]*/; do
        [ "$pid_dir" = "/proc/$$/" ] && continue
        if grep -qa "php" "${pid_dir}cmdline" 2>/dev/null && \
           grep -qa "artisan" "${pid_dir}cmdline" 2>/dev/null && \
           grep -qa "horizon" "${pid_dir}cmdline" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

if check_process; then
    log_info "Horizon 进程正常"
    exit 0
else
    log_err "Horizon 进程异常"
    exit 1
fi
