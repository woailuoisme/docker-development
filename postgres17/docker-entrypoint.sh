#!/bin/bash
set -e

# PostgreSQL 动态配置选择脚本
# 根据环境变量 POSTGRES_CONFIG_PROFILE 选择配置文件

echo "==================================="
echo "PostgreSQL 启动中..."
echo "==================================="

# 配置文件映射
# 支持的配置：1c1g, 2c2g, 4c8g, custom
POSTGRES_CONFIG_PROFILE="${POSTGRES_CONFIG_PROFILE:-1c1g}"

echo "配置档案: $POSTGRES_CONFIG_PROFILE"

# 根据配置档案选择配置文件
case "$POSTGRES_CONFIG_PROFILE" in
    1c1g)
        CONFIG_FILE="/etc/postgresql/postgresql.conf"
        echo "使用配置: 1核1G (默认)"
        ;;
    2c2g)
        CONFIG_FILE="/etc/postgresql/postgresql-2c2g.conf"
        echo "使用配置: 2核2G"
        ;;
    4c8g)
        CONFIG_FILE="/etc/postgresql/postgresql-4c8g.conf"
        echo "使用配置: 4核8G"
        ;;
    custom)
        CONFIG_FILE="${POSTGRES_CUSTOM_CONFIG:-/etc/postgresql/postgresql.conf}"
        echo "使用自定义配置: $CONFIG_FILE"
        ;;
    *)
        echo "警告: 未知的配置档案 '$POSTGRES_CONFIG_PROFILE'，使用默认配置"
        CONFIG_FILE="/etc/postgresql/postgresql.conf"
        ;;
esac

# 验证配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    echo "回退到默认配置"
    CONFIG_FILE="/etc/postgresql/postgresql.conf"
fi

echo "配置文件: $CONFIG_FILE"
echo "==================================="

# 设置 PostgreSQL 配置文件环境变量
export POSTGRES_CONFIG_FILE="$CONFIG_FILE"

# 显示配置信息
echo "PostgreSQL 版本: $(postgres --version)"
echo "数据库: ${POSTGRES_DB:-postgres}"
echo "用户: ${POSTGRES_USER:-postgres}"
echo "最大连接数: $(grep -E '^max_connections' "$CONFIG_FILE" | awk '{print $3}' || echo '未设置')"
echo "共享缓冲区: $(grep -E '^shared_buffers' "$CONFIG_FILE" | awk '{print $3}' || echo '未设置')"
echo "==================================="

# 调用原始的 PostgreSQL entrypoint
exec docker-entrypoint.sh postgres -c "config_file=$CONFIG_FILE"
