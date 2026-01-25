#!/bin/bash
set -e

echo "==================================="
echo "PgBouncer 启动中..."
echo "==================================="

PGBOUNCER_CONFIG="/etc/pgbouncer/pgbouncer.ini"
PGBOUNCER_AUTH_FILE="/etc/pgbouncer/userlist.txt"

# 环境变量默认值
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-lunchbox}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

# 验证密码
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "错误: POSTGRES_PASSWORD 未设置"
    exit 1
fi

# ============================================================================
# 等待 PostgreSQL 启动
# ============================================================================
echo "等待 PostgreSQL 启动..."
for i in {1..30}; do
    if pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" >/dev/null 2>&1; then
        echo "PostgreSQL 已就绪"
        break
    fi
    [ $i -eq 30 ] && echo "错误: PostgreSQL 启动超时" && exit 1
    sleep 2
done

# ============================================================================
# 获取密码哈希并生成 userlist.txt
# ============================================================================
echo "生成用户认证文件..."

# 获取主用户密码哈希
SCRAM=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A \
    -c "SELECT rolpassword FROM pg_authid WHERE rolname = '$POSTGRES_USER';" 2>&1 | tr -d '[:space:]')

# 验证哈希
if [[ -z "$SCRAM" || "$SCRAM" == *"ERROR"* || "$SCRAM" == *"FATAL"* ]]; then
    echo "警告: 使用明文密码"
    SCRAM="$POSTGRES_PASSWORD"
fi

# 写入主用户
echo "\"$POSTGRES_USER\" \"$SCRAM\"" > "$PGBOUNCER_AUTH_FILE"

# 添加管理用户
if [ -n "$PGBOUNCER_ADMIN_USER" ] && [ -n "$PGBOUNCER_ADMIN_PASSWORD" ]; then
    ADMIN_SCRAM=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A \
        -c "SELECT rolpassword FROM pg_authid WHERE rolname = '$PGBOUNCER_ADMIN_USER';" 2>&1 | tr -d '[:space:]')
    [[ -z "$ADMIN_SCRAM" || "$ADMIN_SCRAM" == *"ERROR"* ]] && ADMIN_SCRAM="$PGBOUNCER_ADMIN_PASSWORD"
    echo "\"$PGBOUNCER_ADMIN_USER\" \"$ADMIN_SCRAM\"" >> "$PGBOUNCER_AUTH_FILE"
else
    echo "\"pgbouncer\" \"$SCRAM\"" >> "$PGBOUNCER_AUTH_FILE"
fi

# 添加额外用户
if [ -n "$PGBOUNCER_EXTRA_USERS" ]; then
    IFS=',' read -ra USERS <<< "$PGBOUNCER_EXTRA_USERS"
    for user_pass in "${USERS[@]}"; do
        IFS=':' read -r user pass <<< "$user_pass"
        [ -z "$user" ] || [ -z "$pass" ] && continue
        
        USER_SCRAM=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
            -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A \
            -c "SELECT rolpassword FROM pg_authid WHERE rolname = '$user';" 2>&1 | tr -d '[:space:]')
        [[ -z "$USER_SCRAM" || "$USER_SCRAM" == *"ERROR"* ]] && USER_SCRAM="$pass"
        echo "\"$user\" \"$USER_SCRAM\"" >> "$PGBOUNCER_AUTH_FILE"
    done
fi

chmod 600 "$PGBOUNCER_AUTH_FILE"

echo "==================================="
echo "PostgreSQL: $POSTGRES_HOST:$POSTGRES_PORT"
echo "数据库: $POSTGRES_DB"
echo "用户: $POSTGRES_USER"
echo "==================================="

# 信号处理
trap 'echo "关闭中..."; kill -TERM $(cat /var/run/pgbouncer/pgbouncer.pid 2>/dev/null) 2>/dev/null; exit 0' SIGTERM SIGINT SIGQUIT

echo "PgBouncer 启动完成"
echo ""

exec pgbouncer "$PGBOUNCER_CONFIG"
