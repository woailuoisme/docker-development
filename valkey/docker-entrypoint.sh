#!/bin/sh
set -e

# 如果环境变量设置了密码，且启动命令是 valkey-server
if [ -n "$VALKEY_PASSWORD" ] && [ "$1" = 'valkey-server' ]; then
    # 自动追加 --requirepass 参数
    set -- "$@" --requirepass "$VALKEY_PASSWORD"
fi

# 使用 exec 替换当前进程，确保信号能正确传递 (优雅停机)
exec "$@"
