#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HAProxy 3.4 启动、配置模块化 (include) 与运行时管理脚本
# ==============================================================================

CERTS_DIR="/etc/haproxy/certs"
SSL_DIR="/etc/haproxy/ssl/live"
MAIN_CFG="/usr/local/etc/haproxy/haproxy.cfg"
COMPILED_CFG="/var/lib/haproxy/haproxy.cfg"
STATS_SOCK="/var/lib/haproxy/stats.sock"
DOMAIN="${SITE_ADDRESS:-test.local}"

MAPS_SRC_DIR="/usr/local/etc/haproxy/maps"
MAPS_DST_DIR="/var/lib/haproxy/maps"

# 0. 动态配置时区
setup_timezone() {
	if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
		ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
		echo "${TZ}" > /etc/timezone
	fi
}

# 1. 同步 Lego 证书与冷启动自签兜底
sync_certificates() {
	mkdir -p "${CERTS_DIR}" /var/lib/haproxy

	if [ -d "${SSL_DIR}" ]; then
		for d in "${SSL_DIR}"/*; do
			[ -d "${d}" ] || continue
			local name
			name="$(basename "${d}")"
			if [ -f "${d}/haproxy.pem" ]; then
				ln -snf "${d}/haproxy.pem" "${CERTS_DIR}/${name}.pem" 2> /dev/null || cp -f "${d}/haproxy.pem" "${CERTS_DIR}/${name}.pem"
			elif [ -f "${d}/fullchain.pem" ] && [ -f "${d}/privkey.pem" ]; then
				cat "${d}/fullchain.pem" "${d}/privkey.pem" > "${CERTS_DIR}/${name}.pem"
			fi
		done
	fi

	# 冷启动自签证书防崩保护
	if ! compgen -G "${CERTS_DIR}/*.pem" > /dev/null; then
		openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
			-keyout /tmp/self.key -out /tmp/self.crt \
			-subj "/CN=${DOMAIN}" 2> /dev/null
		cat /tmp/self.crt /tmp/self.key > "${CERTS_DIR}/00-default.pem"
		rm -f /tmp/self.key /tmp/self.crt
	fi

	chmod 600 "${CERTS_DIR}"/*.pem 2> /dev/null || true
	chown -R haproxy:haproxy /var/lib/haproxy "${CERTS_DIR}" 2> /dev/null || true
}

# 2. 环境变量动态模板替换 (${SITE_ADDRESS} / ${HAPROXY_STATS_USER} / ${HAPROXY_STATS_PASSWORD} / maps 路径映射)
substitute_env() {
	local domain="${SITE_ADDRESS:-test.local}"
	local stats_user="${HAPROXY_STATS_USER:-admin}"
	local stats_pass="${HAPROXY_STATS_PASSWORD:-admin}"

	local sed_args=(
		-e "s/\\$\{SITE_ADDRESS:-[^}]+\}/${domain}/g"
		-e "s/\\$\{SITE_ADDRESS\}/${domain}/g"
		-e "s/\\{\\\$SITE_ADDRESS\\}/${domain}/g"
		-e "s/\\\$SITE_ADDRESS/${domain}/g"
		-e "s/\\$\{HAPROXY_STATS_USER:-[^}]+\}/${stats_user}/g"
		-e "s/\\$\{HAPROXY_STATS_USER\}/${stats_user}/g"
		-e "s/\\$\{HAPROXY_STATS_PASSWORD:-[^}]+\}/${stats_pass}/g"
		-e "s/\\$\{HAPROXY_STATS_PASSWORD\}/${stats_pass}/g"
		-e "s#/usr/local/etc/haproxy/maps/#/var/lib/haproxy/maps/#g"
	)

	if [ -z "${SITE_ADDRESS:-}" ]; then
		sed_args+=(-e "s/\\$\{SITE_ADDRESS:-([^}]+)\}/\1/g")
	fi

	sed -E "${sed_args[@]}"
}

# 3. 预处理与编译 maps 路由表 (支持 ${SITE_ADDRESS} 替换)
compile_maps() {
	mkdir -p "${MAPS_DST_DIR}"
	if [ -d "${MAPS_SRC_DIR}" ]; then
		shopt -s nullglob
		for file in "${MAPS_SRC_DIR}"/*; do
			[ -f "${file}" ] || continue
			target_name="$(basename "${file}")"
			substitute_env < "${file}" > "${MAPS_DST_DIR}/${target_name}"
		done
		shopt -u nullglob
	fi
	chown -R haproxy:haproxy "${MAPS_DST_DIR}" 2> /dev/null || true
	chmod 644 "${MAPS_DST_DIR}"/* 2> /dev/null || true
}

# 4. 递归展开 include 指令 (类似 Nginx include 行为)
expand_config() {
	local file="$1"
	local depth="${2:-0}"

	if [ "${depth}" -gt 10 ]; then
		echo "# Error: Maximum include depth exceeded in ${file}" >&2
		return 1
	fi

	[ -f "${file}" ] || return 0

	while IFS= read -r line || [ -n "${line}" ]; do
		if [[ ! "${line}" =~ ^[[:space:]]*include[[:space:]]+(.+)$ ]]; then
			echo "${line}"
			continue
		fi

		local pattern
		pattern="$(echo "${BASH_REMATCH[1]}" | sed -E "s/^[[:space:]\"']+|[[:space:]\"';]+$//g")"

		shopt -s nullglob
		# shellcheck disable=SC2206
		local matches=(${pattern})
		shopt -u nullglob

		if [ ${#matches[@]} -eq 0 ]; then
			echo "# [include: no files matched ${pattern}]"
			continue
		fi

		for match in "${matches[@]}"; do
			[ -f "${match}" ] || continue
			echo "# --- Included from: ${match} ---"
			expand_config "${match}" "$((depth + 1))"
		done
	done < "${file}"
}

# 5. 预编译主配置与语法检测
compile_config() {
	compile_maps
	if [ ! -f "${MAIN_CFG}" ]; then
		echo "[ERROR] Main configuration file not found: ${MAIN_CFG}" >&2
		return 1
	fi
	mkdir -p "$(dirname "${COMPILED_CFG}")"
	local tmp="${COMPILED_CFG}.tmp"
	expand_config "${MAIN_CFG}" | substitute_env > "${tmp}"

	if ! haproxy -c -f "${tmp}" > /dev/null 2>&1; then
		echo "[ERROR] HAProxy configuration validation failed:" >&2
		haproxy -c -f "${tmp}" >&2 || true
		rm -f "${tmp}"
		return 1
	fi

	mv -f "${tmp}" "${COMPILED_CFG}"
	chown haproxy:haproxy "${COMPILED_CFG}" 2> /dev/null || true
	chmod 644 "${COMPILED_CFG}" 2> /dev/null || true
}

# 6. CLI 命令实现 (check / reload / cli)
check_config() {
	compile_maps
	local tmp
	tmp="$(mktemp)"
	trap 'rm -f "${tmp}"' RETURN
	expand_config "${MAIN_CFG}" | substitute_env > "${tmp}"
	haproxy -c -f "${tmp}"
	echo "[SUCCESS] Configuration syntax is valid."
}

reload_service() {
	echo "[INFO] Recompiling HAProxy configurations and maps..."
	sync_certificates
	compile_config
	echo "[INFO] Sending reload signal to HAProxy master process..."
	kill -USR2 1 2> /dev/null || kill -HUP 1 2> /dev/null || true
	echo "[SUCCESS] HAProxy configuration reloaded successfully."
}

stats_cli() {
	if [ ! -S "${STATS_SOCK}" ]; then
		echo "[ERROR] HAProxy stats socket not found: ${STATS_SOCK}" >&2
		return 1
	fi
	local query="${*:-help}"
	echo "${query}" | socat stdio "${STATS_SOCK}"
}

# --- CLI 子命令分发 ---
action="${1:-}"
case "${action}" in
	check | --check)
		check_config
		exit 0
		;;
	reload | --reload)
		reload_service
		exit 0
		;;
	cli | --cli)
		shift
		stats_cli "$@"
		exit 0
		;;
esac

case "$(basename "$0")" in
	haproxy-check)
		check_config
		exit 0
		;;
	haproxy-reload)
		reload_service
		exit 0
		;;
	haproxy-cli)
		stats_cli "$@"
		exit 0
		;;
esac

# --- 容器主服务启动流程 ---
setup_timezone
sync_certificates
compile_config

# 将启动参数中的主配置路径重定向至已展开 include 的编译配置
args=()
for arg in "$@"; do
	[ "${arg}" = "${MAIN_CFG}" ] && args+=("${COMPILED_CFG}") || args+=("${arg}")
done

exec "${args[@]}"
