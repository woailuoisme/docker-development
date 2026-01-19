#!/bin/bash

# Laravel Queue Worker 健康检查脚本
# 用于 Docker HEALTHCHECK 指令

set -e

# 检查 Worker 进程是否在运行
check_worker_process() {
    # 方法1: 检查 php artisan queue:work 进程
    if pgrep -f "php.*artisan.*queue:work" > /dev/null; then
        return 0
    fi

    # 如果有 supervisor，检查 supervisor 状态
    if [ -f "/usr/bin/supervisorctl" ] || [ -f "/usr/local/bin/supervisorctl" ]; then
         if supervisorctl status worker | grep -q "RUNNING"; then
            return 0
        fi
    fi

    return 1
}

# 主健康检查逻辑
main() {
    if check_worker_process; then
        echo "OK: Queue Worker is running"
        exit 0
    else
        echo "ERROR: Queue Worker is not running"
        exit 1
    fi
}

# 运行主函数
main "$@"
