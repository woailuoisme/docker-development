#!/bin/bash
set -e

# PgBouncer 启动脚本
# 提供配置验证、环境变量替换、动态生成 userlist、优雅启动和信号处理

echo "==================================="
echo "PgBouncer 启动中..."
echo "==================================="

# 环境变量配置
PGBOUNCER_CONFIG_TEMPLATE="${PGBOUNCER_CONFIG_TEMPLATE:-/etc/pgbouncer/pgbouncer.envsubst.ini}"
PGBOUNCER_CONFIG="/etc/pgbouncer/pgbouncer.ini"
PGBOUNCER_AUTH_FILE="/etc/pgbouncer/userlist.txt"

# 设置默认值
export POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
export POSTGRES_PORT="${POSTGRES_PORT:-5432}"
export POSTGRES_DB="${POSTGRES_DB:-lunchbox}"
export POSTGRES_USER="${POSTGRES_USER:-postgres}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

export MAX_CLIENT_CONN="${MAX_CLIENT_CONN:-200}"
export DEFAULT_POOL_SIZE="${DEFAULT_POOL_SIZE:-25}"
export MIN_POOL_SIZE="${MIN_POOL_SIZE:-5}"
export RESERVE_POOL_SIZE="${RESERVE_POOL_SIZE:-5}"
export MAX_DB_CONNECTIONS="${MAX_DB_CONNECTIONS:-50}"
export MAX_USER_CONNECTIONS="${MAX_USER_CONNECTIONS:-50}"

export QUERY_WAIT_TIMEOUT="${QUERY_WAIT_TIMEOUT:-120}"
export SERVER_IDLE_TIMEOUT="${SERVER_IDLE_TIMEOUT:-600}"
export SERVER_LIFETIME="${SERVER_LIFETIME:-3600}"

export LOG_CONNECTIONS="${LOG_CONNECTIONS:-1}"
export LOG_DISCONNECTIONS="${LOG_DISCONNECTIONS:-1}"
export VERBOSE="${VERBOSE:-0}"

# 验证必需的环境变量
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "错误: POSTGRES_PASSWORD 环境变量未设置"
    exit 1
fi

# 验证模板配置文件
if [ ! -f "$PGBOUNCER_CONFIG_TEMPLATE" ]; then
    echo "错误: 配置模板文件不存在: $PGBOUNCER_CONFIG_TEMPLATE"
    exit 1
fi

# ============================================================================
# 从 PostgreSQL 获取 SCRAM-SHA-256 密码哈希
# ============================================================================
echo "正在从 PostgreSQL 获取密码哈希..."

# 等待 PostgreSQL 启动
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" > /dev/null 2>&1; then
        echo "PostgreSQL 已就绪"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "等待 PostgreSQL 启动... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "错误: PostgreSQL 未在预期时间内启动"
    exit 1
fi

# 从 PostgreSQL 获取密码哈希
echo "正在获取用户密码哈希..."
SCRAM_PASSWORD=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "SELECT rolpassword FROM pg_authid WHERE rolname = '$POSTGRES_USER';" 2>&1)

# 清理结果（移除所有空白字符）
SCRAM_PASSWORD=$(echo "$SCRAM_PASSWORD" | tr -d '[:space:]')

if [ -z "$SCRAM_PASSWORD" ] || [ "$SCRAM_PASSWORD" = "" ] || [[ "$SCRAM_PASSWORD" == *"ERROR"* ]] || [[ "$SCRAM_PASSWORD" == *"FATAL"* ]]; then
    echo "警告: 无法从 PostgreSQL 获取密码哈希，使用明文密码"
    echo "错误信息: $SCRAM_PASSWORD"
    SCRAM_PASSWORD="$POSTGRES_PASSWORD"
else
    echo "成功获取 SCRAM-SHA-256 密码哈希"
fi

# ============================================================================
# 动态生成 userlist.txt（使用 SCRAM-SHA-256）
# ============================================================================
echo "正在生成用户认证文件..."

# 添加主数据库用户（使用从 PostgreSQL 获取的 SCRAM 哈希）
echo "\"$POSTGRES_USER\" \"$SCRAM_PASSWORD\"" > "$PGBOUNCER_AUTH_FILE"

# 添加 pgbouncer 管理用户（如果提供）
if [ -n "$PGBOUNCER_ADMIN_USER" ] && [ -n "$PGBOUNCER_ADMIN_PASSWORD" ]; then
    # 尝试从 PostgreSQL 获取管理用户的密码哈希
    ADMIN_SCRAM=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "SELECT rolpassword FROM pg_authid WHERE rolname = '$PGBOUNCER_ADMIN_USER';" 2>&1 | tr -d '[:space:]')
    if [ -z "$ADMIN_SCRAM" ] || [[ "$ADMIN_SCRAM" == *"ERROR"* ]]; then
        ADMIN_SCRAM="$PGBOUNCER_ADMIN_PASSWORD"
    fi
    echo "\"$PGBOUNCER_ADMIN_USER\" \"$ADMIN_SCRAM\"" >> "$PGBOUNCER_AUTH_FILE"
else
    # 使用默认管理用户（与数据库用户相同）
    echo "\"pgbouncer\" \"$SCRAM_PASSWORD\"" >> "$PGBOUNCER_AUTH_FILE"
fi

# 添加额外用户（如果提供，格式：user1:pass1,user2:pass2）
if [ -n "$PGBOUNCER_EXTRA_USERS" ]; then
    IFS=',' read -ra USERS <<< "$PGBOUNCER_EXTRA_USERS"
    for user_pass in "${USERS[@]}"; do
        IFS=':' read -r user pass <<< "$user_pass"
        if [ -n "$user" ] && [ -n "$pass" ]; then
            # 尝试从 PostgreSQL 获取用户的密码哈希
            USER_SCRAM=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "SELECT rolpassword FROM pg_authid WHERE rolname = '$user';" 2>&1 | tr -d '[:space:]')
            if [ -z "$USER_SCRAM" ] || [[ "$USER_SCRAM" == *"ERROR"* ]]; then
                USER_SCRAM="$pass"
            fi
            echo "\"$user\" \"$USER_SCRAM\"" >> "$PGBOUNCER_AUTH_FILE"
        fi
    done
fi

# 设置正确的权限
chmod 600 "$PGBOUNCER_AUTH_FILE"

echo "用户认证文件已生成: $PGBOUNCER_AUTH_FILE"

# ============================================================================
# 生成配置文件（替换环境变量）
# ============================================================================
echo "正在生成配置文件..."

# 使用 envsubst 替换环境变量
envsubst < "$PGBOUNCER_CONFIG_TEMPLATE" > "$PGBOUNCER_CONFIG"

# 验证生成的配置
if [ ! -s "$PGBOUNCER_CONFIG" ]; then
    echo "错误: 配置文件生成失败"
    exit 1
fi

# 设置正确的权限
chmod 644 "$PGBOUNCER_CONFIG"

echo "配置文件已生成: $PGBOUNCER_CONFIG"

# 显示配置信息
echo "==================================="
echo "配置信息:"
echo "==================================="
echo "PostgreSQL 主机: $POSTGRES_HOST"
echo "PostgreSQL 端口: $POSTGRES_PORT"
echo "数据库名称: $POSTGRES_DB"
echo "数据库用户: $POSTGRES_USER"
echo "认证类型: scram-sha-256"
echo "-----------------------------------"
echo "最大客户端连接: $MAX_CLIENT_CONN"
echo "默认连接池大小: $DEFAULT_POOL_SIZE"
echo "最小连接池大小: $MIN_POOL_SIZE"
echo "保留连接池大小: $RESERVE_POOL_SIZE"
echo "最大数据库连接: $MAX_DB_CONNECTIONS"
echo "-----------------------------------"
echo "查询等待超时: ${QUERY_WAIT_TIMEOUT}s"
echo "服务器空闲超时: ${SERVER_IDLE_TIMEOUT}s"
echo "服务器生命周期: ${SERVER_LIFETIME}s"
echo "==================================="

# 信号处理函数
shutdown() {
    echo ""
    echo "==================================="
    echo "收到停止信号，正在优雅关闭..."
    echo "==================================="
    
    # 发送 SIGTERM 给 pgbouncer 进程
    if [ -f /var/run/pgbouncer/pgbouncer.pid ]; then
        PID=$(cat /var/run/pgbouncer/pgbouncer.pid)
        if kill -0 "$PID" 2>/dev/null; then
            echo "正在关闭 PgBouncer (PID: $PID)..."
            kill -TERM $PID
            
            # 等待进程退出
            for i in {1..30}; do
                if ! kill -0 $PID 2>/dev/null; then
                    echo "PgBouncer 已成功关闭"
                    exit 0
                fi
                sleep 1
            done
            
            echo "警告: PgBouncer 未在30秒内关闭，强制终止"
            kill -KILL $PID 2>/dev/null || true
        fi
    fi
    
    exit 0
}

# 注册信号处理
trap shutdown SIGTERM SIGINT SIGQUIT

echo "==================================="
echo "PgBouncer 启动完成"
echo "==================================="
echo ""

# 使用生成的配置文件启动 pgbouncer
exec pgbouncer "$PGBOUNCER_CONFIG"
