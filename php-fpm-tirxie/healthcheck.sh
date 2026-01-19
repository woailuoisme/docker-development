#!/bin/bash

# PHP-FPM 健康检查脚本
set -e

# 日志工具
RED='\033[0;31m' GREEN='\033[0;32m' NC='\033[0m'
log() { echo -e "${1}[$(date '+%Y-%m-%d %H:%M:%S %z')] [HEALTH]${NC} ${2}" >&2; }
log_info() { log "${GREEN}" "$1"; }
log_err()  { log "${RED}" "$1"; }

# 1. 检查 FPM Master 进程 (避开自身)
check_process() {
    for pid_dir in /proc/[0-9]*/; do
        [ "$pid_dir" = "/proc/$$/" ] && continue
        # 匹配 php-fpm: master process
        if grep -qa "php-fpm" "${pid_dir}cmdline" 2>/dev/null && \
           grep -qa "master" "${pid_dir}cmdline" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

if check_process; then
    log_info "PHP-FPM Master 进程正常"
    exit 0
else
    log_err "PHP-FPM 进程异常"
    exit 1
fi
