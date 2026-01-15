#!/bin/bash

# Laravel Horizon 健康检查脚本
# 用于 Docker HEALTHCHECK 指令

set -e

# 检查 Horizon 进程是否在运行
check_horizon_process() {
    # 方法1: 检查 Horizon 进程
    if pgrep -f "php.*artisan.*horizon" > /dev/null; then
        return 0
    fi

    # 方法2: 检查 Horizon 状态命令
    if [ -f "/var/www/lunchbox/artisan" ]; then
        cd /var/www/lunchbox
        if php artisan horizon:status --quiet 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# 主健康检查逻辑
main() {
    if check_horizon_process; then
        echo "OK: Laravel Horizon is running"
        exit 0
    else
        echo "ERROR: Laravel Horizon is not running"
        exit 1
    fi
}

# 运行主函数
main "$@"
