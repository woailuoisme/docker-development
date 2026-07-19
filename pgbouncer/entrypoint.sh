#!/bin/sh
set -e

# 日志工具
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
log() { echo -e "${1}[$(date '+%Y-%m-%d %H:%M:%S %z')] [${2}]${NC} ${3}"; }
log_info() { log "${BLUE}" "INFO" "$1"; }
log_success() { log "${GREEN}" "SUCCESS" "$1"; }
log_warning() { log "${YELLOW}" "WARNING" "$1" >&2; }
log_error() { log "${RED}" "ERROR" "$1" >&2; }

log_info "PgBouncer 启动中..."

PGBOUNCER_CONFIG="/etc/pgbouncer/pgbouncer.ini"
PGBOUNCER_AUTH_FILE="/etc/pgbouncer/userlist.txt"

# 环境变量默认值
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-lunchbox}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

# 验证密码
if [ -z "$POSTGRES_PASSWORD" ]; then
	log_error "POSTGRES_PASSWORD 未设置"
	exit 1
fi

# 优雅停机信号处理
trap 'log_info "收到终止信号，正在停止 PgBouncer..."; kill -TERM "$PGBOUNCER_PID" 2>/dev/null || true; wait "$PGBOUNCER_PID"' TERM INT QUIT

# 等待 PostgreSQL 数据库就绪
log_info "等待 PostgreSQL 数据库上线 ($POSTGRES_HOST:$POSTGRES_PORT)..."
attempts=0
max_attempts=30

while ! pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; do
	attempts=$((attempts + 1))
	if [ "$attempts" -ge "$max_attempts" ]; then
		log_error "等待 PostgreSQL 超时 (30秒)，启动失败"
		exit 1
	fi
	log_info "PostgreSQL 尚未就绪，等待中... (${attempts}/${max_attempts})"
	sleep 1
done

log_success "PostgreSQL 数据库已成功上线！"

# Helper Function: Query SCRAM password hash from database
get_scram_hash() {
	local target_user="$1"
	local default_pass="$2"
	local query_sql="SELECT concat('\"', rolname, '\" \"', rolpassword, '\"') FROM pg_authid WHERE rolname = '$target_user';"

	local scram_hash
	scram_hash=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "$query_sql" 2> /dev/null || true)

	if [ -n "$scram_hash" ]; then
		echo "$scram_hash"
	else
		echo "\"$target_user\" \"$default_pass\""
	fi
}

# Helper Function: Write user entry to userlist.txt if user non-empty
write_user_auth() {
	local user="$1"
	local pass="$2"
	if [ -n "$user" ]; then
		local entry
		entry=$(get_scram_hash "$user" "$pass")
		echo "$entry" >> "$PGBOUNCER_AUTH_FILE"
		log_info "已为此用户添加认证配置: $user"
	fi
}

log_info "从 PostgreSQL 动态生成 authentication userlist.txt..."
rm -f "$PGBOUNCER_AUTH_FILE"
touch "$PGBOUNCER_AUTH_FILE"
chmod 600 "$PGBOUNCER_AUTH_FILE"

# 1. 默认 PostgreSQL 用户
write_user_auth "$POSTGRES_USER" "$POSTGRES_PASSWORD"

# 2. 管理员用户
ADMIN_USER="${PGBOUNCER_ADMIN_USER:-$POSTGRES_USER}"
ADMIN_PASS="${PGBOUNCER_ADMIN_PASSWORD:-$POSTGRES_PASSWORD}"
if [ "$ADMIN_USER" != "$POSTGRES_USER" ]; then
	write_user_auth "$ADMIN_USER" "$ADMIN_PASS"
fi

# 3. 额外用户列表
if [ -n "$PGBOUNCER_EXTRA_USERS" ]; then
	log_info "正在处理额外用户配置..."
	OLD_IFS="$IFS"
	IFS=','
	for extra_user in $PGBOUNCER_EXTRA_USERS; do
		# 清理空格
		clean_user=$(echo "$extra_user" | tr -d ' ')
		if [ -n "$clean_user" ] && [ "$clean_user" != "$POSTGRES_USER" ] && [ "$clean_user" != "$ADMIN_USER" ]; then
			write_user_auth "$clean_user" "$POSTGRES_PASSWORD"
		fi
	done
	IFS="$OLD_IFS"
fi

log_success "userlist.txt 配置已成功生成！"
log_info "正在前台启动 PgBouncer 服务..."

# 启动 pgbouncer 并记录 PID
pgbouncer "$PGBOUNCER_CONFIG" &
PGBOUNCER_PID=$!

log_success "PgBouncer 已就绪，进程 PID: $PGBOUNCER_PID"
wait "$PGBOUNCER_PID"
