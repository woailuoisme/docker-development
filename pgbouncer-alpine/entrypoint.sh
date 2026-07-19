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

# Helper: 查询 PostgreSQL 中的用户密码哈希，如果查询失败则使用默认明文/给定哈希
get_scram_hash() {
	_user="$1"
	_default_pass="$2"

	_hash=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
		-U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A \
		-c "SELECT rolpassword FROM pg_authid WHERE rolname = '$_user';" 2>&1 | tr -d '[:space:]')

	case "$_hash" in
		"" | *ERROR* | *FATAL*)
			# 如果查询失败（例如权限不足或用户不存在），回退到原密码/给定值
			log_warning "查询用户 $_user 密码哈希失败，将使用明文密码"
			echo "$_default_pass"
			;;
		*)
			echo "$_hash"
			;;
	esac
}

# Helper: 写入用户认证信息到 userlist.txt
write_user_auth() {
	echo "\"$1\" \"$2\"" >> "$PGBOUNCER_AUTH_FILE"
}

# ============================================================================
# 等待 PostgreSQL 启动
# ============================================================================
log_info "等待 PostgreSQL 启动..."
i=1
while ! pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" > /dev/null 2>&1; do
	if [ "$i" -eq 30 ]; then
		log_error "PostgreSQL 启动超时"
		exit 1
	fi
	i=$((i + 1))
	sleep 2
done
log_success "PostgreSQL 已就绪"

# ============================================================================
# 获取密码哈希并生成 userlist.txt
# ============================================================================
log_info "生成用户认证文件..."

# 初始化并设置权限
: > "$PGBOUNCER_AUTH_FILE"
chmod 600 "$PGBOUNCER_AUTH_FILE"

# 1. 写入主用户
write_user_auth "$POSTGRES_USER" "$(get_scram_hash "$POSTGRES_USER" "$POSTGRES_PASSWORD")"

# 2. 写入管理用户
if [ -n "$PGBOUNCER_ADMIN_USER" ] && [ -n "$PGBOUNCER_ADMIN_PASSWORD" ]; then
	write_user_auth "$PGBOUNCER_ADMIN_USER" "$(get_scram_hash "$PGBOUNCER_ADMIN_USER" "$PGBOUNCER_ADMIN_PASSWORD")"
else
	# 默认额外添加 pgbouncer 管理用户 (密码与主用户相同)
	write_user_auth "pgbouncer" "$(get_scram_hash "$POSTGRES_USER" "$POSTGRES_PASSWORD")"
fi

# 3. 写入额外用户 (格式：user1:pass1,user2:pass2)
if [ -n "$PGBOUNCER_EXTRA_USERS" ]; then
	old_ifs="$IFS"
	IFS=','
	for user_pass in $PGBOUNCER_EXTRA_USERS; do
		IFS="$old_ifs"
		case "$user_pass" in
			*:*)
				user="${user_pass%%:*}"
				pass="${user_pass#*:}"
				if [ -n "$user" ] && [ -n "$pass" ]; then
					log_info "正在查询额外用户 $user 的密码哈希..."
					write_user_auth "$user" "$(get_scram_hash "$user" "$pass")"
				fi
				;;
		esac
		IFS=','
	done
	IFS="$old_ifs"
fi

log_info "配置信息 - PostgreSQL: $POSTGRES_HOST:$POSTGRES_PORT"
log_info "配置信息 - 数据库: $POSTGRES_DB"
log_info "配置信息 - 用户: $POSTGRES_USER"

# 信号处理
trap 'log_info "关闭中..."; kill -TERM $(cat /var/run/pgbouncer/pgbouncer.pid 2>/dev/null) 2>/dev/null; exit 0' TERM INT QUIT

log_success "PgBouncer 启动完成"
echo ""

exec pgbouncer "$PGBOUNCER_CONFIG"
