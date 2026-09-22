#!/usr/bin/env bash
# ==============================================================================
# OpenBao 引擎、动态凭据与访问策略供给脚本（幂等，可反复执行）
# ==============================================================================
# 1. 引擎：KV v2 (secret/) 与 database
# 2. 动态凭据：Valkey 连接配置 + app-ro / app-rw 两个 ACL 动态角色
# 3. 访问侧：校验声明式审计设备、启用 AppRole、上传策略并签发 secret_id
#
# 依赖：容器 open-bao（已初始化且已解封）、宿主机 jq
# 凭据：Valkey 管理口令取自仓库根 .env 的 REDIS_PASSWORD
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [ -f "${ROOT_DIR}/.env" ]; then
	set -a
	# shellcheck disable=SC1091
	. "${ROOT_DIR}/.env"
	set +a
fi

readonly CONTAINER_NAME="open-bao"
readonly IN_CONTAINER_ADDR="http://127.0.0.1:8200"
readonly KEY_FILE="${SCRIPT_DIR}/.keys.json"
readonly POLICY_DIR="${SCRIPT_DIR}/config/policies"
readonly APPROLE_CRED_FILE="${SCRIPT_DIR}/.approle-credentials.txt"

readonly DB_CONN_NAME="valkey"
readonly DB_HOST="valkey"
readonly DB_PORT="6379"
readonly ROLE_RO="app-ro"
readonly ROLE_RW="app-rw"
readonly TTL="1h"
readonly MAX_TTL="24h"
readonly ACL_RO='["~*", "+@read", "+@connection"]'
readonly ACL_RW='["~*", "+@read", "+@write", "+@connection"]'

log() { printf '[%s] %s\n' "$1" "$2"; }
info() { log INFO "$*"; }
ok() { log SUCCESS "$*"; }
warn() { log WARN "$*"; }
die() {
	log ERROR "$*" >&2
	exit 1
}

for cmd in docker jq; do
	command -v "${cmd}" > /dev/null 2>&1 || die "缺少依赖命令: ${cmd}"
done

docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}" \
	|| die "容器 ${CONTAINER_NAME} 未运行，请先执行: docker compose up -d --build open-bao"

[ -n "${REDIS_PASSWORD:-}" ] \
	|| die "未取得 Valkey 管理口令（.env 的 REDIS_PASSWORD 为空），OpenBao 需以管理员身份连接 Valkey 才能创建 ACL 用户"

ROOT_TOKEN="${BAO_TOKEN:-}"
if [ -z "${ROOT_TOKEN}" ] && [ -f "${KEY_FILE}" ]; then
	ROOT_TOKEN="$(jq -r '.root_token // empty' "${KEY_FILE}")"
fi
[ -n "${ROOT_TOKEN}" ] || die "未取得根令牌，请先执行: just bao-init && just bao-unseal"

# 容器内统一走 127.0.0.1，避免依赖容器 DNS 解析自身
bao_exec() {
	docker exec -i -e BAO_ADDR="${IN_CONTAINER_ADDR}" -e BAO_TOKEN="${ROOT_TOKEN}" "${CONTAINER_NAME}" bao "$@"
}

# secrets / auth / audit 的 list 接口都返回以挂载路径为键的 JSON
has_mount() {
	bao_exec "$1" list -format=json 2> /dev/null | jq -e --arg p "$2" 'has($p)' > /dev/null 2>&1
}

# 按需启用 secrets 引擎：ensure_mount <挂载路径> <secrets enable 的其余参数...>
ensure_mount() {
	local path="$1"
	shift
	if has_mount secrets "${path}"; then
		info "已挂载 ${path}"
		return 0
	fi
	info "启用 ${path}"
	bao_exec secrets enable "$@" > /dev/null
}

# 写 database 动态角色：create_dynamic_role <角色名> <ACL 规则 JSON>
create_dynamic_role() {
	bao_exec write "database/roles/$1" \
		db_name="${DB_CONN_NAME}" default_ttl="${TTL}" max_ttl="${MAX_TTL}" \
		creation_statements="$2" > /dev/null
}

# 写 AppRole 角色：create_approle_role <角色名> <策略名>
create_approle_role() {
	bao_exec write "auth/approle/role/$1" \
		token_policies="$2" token_ttl="${TTL}" token_max_ttl="${MAX_TTL}" \
		secret_id_ttl=24h secret_id_num_uses=0 > /dev/null
}

provision_engines() {
	ensure_mount "secret/" -path=secret -version=2 kv
	ensure_mount "database/" database

	info "写入 Valkey 连接配置 database/config/${DB_CONN_NAME}"
	# Valkey 插件使用离散参数（host/port/tls），不接受 connection_url；
	# username/password 是 OpenBao 管理 ACL 所用的管理员凭据（默认用户 default）
	bao_exec write "database/config/${DB_CONN_NAME}" \
		plugin_name=valkey-database-plugin \
		host="${DB_HOST}" port="${DB_PORT}" tls=false \
		username=default password="${REDIS_PASSWORD}" \
		allowed_roles="${ROLE_RO},${ROLE_RW}" > /dev/null

	info "写入 ACL 动态角色 ${ROLE_RO} / ${ROLE_RW}"
	# creation_statements 为 ACL 规则 JSON：~* 允许全部键，+@xxx 为命令类别
	create_dynamic_role "${ROLE_RO}" "${ACL_RO}"
	create_dynamic_role "${ROLE_RW}" "${ACL_RW}"
}

provision_access() {
	if has_mount audit "to-file/"; then
		info "审计设备已生效"
	else
		warn "未检测到审计设备：v2.3.2 起只能在 openbao.hcl 的 audit 块中声明"
		warn "改动后重建重启，或 docker kill -s HUP ${CONTAINER_NAME} 使其生效"
	fi

	if has_mount auth "approle/"; then
		info "AppRole 已启用"
	else
		info "启用 AppRole 认证"
		bao_exec auth enable approle > /dev/null
	fi

	info "上传最小权限策略 app-db-ro / app-db-rw"
	local policy
	for policy in app-db-ro app-db-rw; do
		bao_exec policy write "${policy}" - < "${POLICY_DIR}/${policy}.hcl" > /dev/null
	done

	info "创建 AppRole 角色并签发 secret_id"
	create_approle_role "${ROLE_RO}" app-db-ro
	create_approle_role "${ROLE_RW}" app-db-rw

	local role
	{
		echo "# OpenBao AppRole 凭据（重跑 setup.sh 会重新签发 secret_id）"
		for role in "${ROLE_RO}" "${ROLE_RW}"; do
			echo "[${role}]"
			echo "role_id=$(bao_exec read -field=role_id "auth/approle/role/${role}/role-id")"
			echo "secret_id=$(bao_exec write -f -field=secret_id "auth/approle/role/${role}/secret-id")"
		done
	} > "${APPROLE_CRED_FILE}"
	chmod 600 "${APPROLE_CRED_FILE}"
}

provision_engines
provision_access

ok "供给完成"

cat << EOF
  只读凭据 : bao read database/creds/${ROLE_RO}
  读写凭据 : bao read database/creds/${ROLE_RW}
  连接方式 : redis://<动态用户名>:<动态口令>@${DB_HOST}:${DB_PORT}
  AppRole  : ${APPROLE_CRED_FILE}（role_id / secret_id，权限 0600）
  应用接入 : POST /v1/auth/approle/login 换令牌，再 GET /v1/database/creds/<role>
  可选轮换 : just bao-cli write -force database/rotate-root/${DB_CONN_NAME}（不可逆）
  注意     : 动态凭据到期会被自动吊销，应用需处理租约续期或重连
EOF
