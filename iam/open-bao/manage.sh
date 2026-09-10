#!/usr/bin/env bash
# ==============================================================================
# OpenBao 密钥管理与集群运维辅助脚本 (OpenBao Management Tool)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="open-bao"
KEY_FILE="${SCRIPT_DIR}/.keys.json"
BAO_ADDR="http://127.0.0.1:8200"

# 检查依赖与容器状态
check_container_running() {
	if ! docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
		echo "❌ 错误: 容器 '${CONTAINER_NAME}' 未运行。"
		echo "💡 请先启动服务: docker compose up -d open-bao"
		exit 1
	fi
}

# 显示帮助手册
cmd_help() {
	cat << EOF
OpenBao 运维与安全控制管理工具

用法:
  ./manage.sh <command> [arguments...]

可用命令:
  status                   查看 OpenBao 节点初始化、封锁与健康状态
  init [shares] [thresh]   一键初始化集群 (默认: 1 份密钥 / 阈值 1，自动保存至 .keys.json)
  unseal [key]             解封 OpenBao 节点 (默认读取 .keys.json 内的 unseal key)
  login [token]            使用 Root Token 登录并输出登录状态
  cli <args...>            在容器内直接执行 bao 命令行指令 (自动注入 BAO_ADDR 与 Token)
  dev                      启动一次性临时 Dev 开发模式容器 (内存模式，免解封，端口 8200)
  help                     显示本帮助信息

示例:
  ./manage.sh status
  ./manage.sh init
  ./manage.sh unseal
  ./manage.sh cli secrets list
  ./manage.sh cli kv put secret/my-db password=supersecret
  ./manage.sh cli kv get secret/my-db
EOF
}

# 查询状态
cmd_status() {
	check_container_running
	echo "🔍 检查 OpenBao (${CONTAINER_NAME}) 运行状态..."
	docker exec -e BAO_ADDR="${BAO_ADDR}" "${CONTAINER_NAME}" bao status || true
}

# 初始化集群
cmd_init() {
	check_container_running
	local shares="${1:-1}"
	local threshold="${2:-1}"

	if [ -f "${KEY_FILE}" ]; then
		echo "⚠️ 警告: 凭据文件已存在 (${KEY_FILE})，表明集群可能已被初始化。"
		read -r -p "是否强制重新生成并覆盖保存？(y/N): " confirm
		if [[ ! "${confirm}" =~ ^[yY]$ ]]; then
			echo "已取消初始化操作。"
			exit 0
		fi
	fi

	echo "🚀 正在初始化 OpenBao 集群 (Shares: ${shares}, Threshold: ${threshold})..."
	local init_output
	if ! init_output=$(docker exec -e BAO_ADDR="${BAO_ADDR}" "${CONTAINER_NAME}" \
		bao operator init -key-shares="${shares}" -key-threshold="${threshold}" -format=json 2>&1); then
		echo "❌ 初始化失败:"
		echo "${init_output}"
		exit 1
	fi

	# 保存凭证至本地并限制权限为仅所有者可读写
	touch "${KEY_FILE}"
	chmod 600 "${KEY_FILE}"
	echo "${init_output}" > "${KEY_FILE}"

	echo "✔ OpenBao 集群初始化成功！"
	echo "📁 密钥与 Root Token 已安全归档至: ${KEY_FILE} (权限 0600)"
	echo "------------------------------------------------------------"
	if command -v jq > /dev/null 2>&1; then
		echo "🔑 Unseal Key (用于节点解封):"
		jq -r '.unseal_keys_b64[]' "${KEY_FILE}"
		echo "👑 Initial Root Token (超级管理员口令):"
		jq -r '.root_token' "${KEY_FILE}"
	else
		grep -E '"(unseal_keys_b64|root_token)"' "${KEY_FILE}"
	fi
	echo "------------------------------------------------------------"
	echo "💡 接下来可执行: ./manage.sh unseal 完成节点解封"
}

# 解封集群
cmd_unseal() {
	check_container_running
	local unseal_key="${1:-}"

	if [ -z "${unseal_key}" ]; then
		if [ -f "${KEY_FILE}" ]; then
			if command -v jq > /dev/null 2>&1; then
				unseal_key=$(jq -r '.unseal_keys_b64[0]' "${KEY_FILE}")
			else
				unseal_key=$(grep -o '"unseal_keys_b64": \[[^]]*\]' "${KEY_FILE}" | grep -o '"[^"]*"' | sed -n '2p' | tr -d '"')
			fi
		fi
	fi

	if [ -z "${unseal_key}" ] || [ "${unseal_key}" = "null" ]; then
		echo "❌ 未检测到解封密钥，请传入参数: ./manage.sh unseal <unseal_key>"
		exit 1
	fi

	echo "🔓 正在解封 OpenBao 节点..."
	docker exec -e BAO_ADDR="${BAO_ADDR}" "${CONTAINER_NAME}" \
		bao operator unseal "${unseal_key}"
}

# 登录
cmd_login() {
	check_container_running
	local token="${1:-}"

	if [ -z "${token}" ] && [ -f "${KEY_FILE}" ]; then
		if command -v jq > /dev/null 2>&1; then
			token=$(jq -r '.root_token' "${KEY_FILE}")
		else
			token=$(grep -o '"root_token": "[^"]*"' "${KEY_FILE}" | cut -d'"' -f4)
		fi
	fi

	if [ -z "${token}" ] || [ "${token}" = "null" ]; then
		echo "❌ 未检测到 Root Token，请传入参数: ./manage.sh login <token>"
		exit 1
	fi

	echo "🔑 正在使用 Token 登录 OpenBao..."
	docker exec -e BAO_ADDR="${BAO_ADDR}" "${CONTAINER_NAME}" \
		bao login "${token}"
}

# 代理执行 bao CLI
cmd_cli() {
	check_container_running
	if [ "$#" -eq 0 ]; then
		echo "用法: ./manage.sh cli <bao subcommand...>"
		echo "示例: ./manage.sh cli secrets list"
		exit 1
	fi

	local token=""
	if [ -f "${KEY_FILE}" ]; then
		if command -v jq > /dev/null 2>&1; then
			token=$(jq -r '.root_token' "${KEY_FILE}")
		else
			token=$(grep -o '"root_token": "[^"]*"' "${KEY_FILE}" | cut -d'"' -f4)
		fi
	fi

	local docker_tty_flags=()
	if [ -t 0 ] && [ -t 1 ]; then
		docker_tty_flags+=("-it")
	else
		docker_tty_flags+=("-i")
	fi

	if [ -n "${token}" ] && [ "${token}" != "null" ]; then
		docker exec "${docker_tty_flags[@]}" \
			-e BAO_ADDR="${BAO_ADDR}" \
			-e BAO_TOKEN="${token}" \
			"${CONTAINER_NAME}" bao "$@"
	else
		docker exec "${docker_tty_flags[@]}" \
			-e BAO_ADDR="${BAO_ADDR}" \
			"${CONTAINER_NAME}" bao "$@"
	fi
}

# 启动一次性开发模式容器
cmd_dev() {
	echo "⚡ 启动一次性 OpenBao Dev 容器 (端口: 8200, 根 Token: root, 内存存储)..."
	echo "💡 按 Ctrl+C 可停止并自动销毁此临时容器"
	docker run --rm -it \
		--name openbao-dev \
		-p 8200:8200 \
		-e BAO_DEV_ROOT_TOKEN_ID="root" \
		-e BAO_DEV_LISTEN_ADDRESS="0.0.0.0:8200" \
		openbao/openbao:latest \
		server -dev
}

# 主入口分发
main() {
	local cmd="${1:-help}"
	shift || true

	case "${cmd}" in
		status)
			cmd_status
			;;
		init)
			cmd_init "$@"
			;;
		unseal)
			cmd_unseal "$@"
			;;
		login)
			cmd_login "$@"
			;;
		cli)
			cmd_cli "$@"
			;;
		dev)
			cmd_dev
			;;
		help | --help | -h)
			cmd_help
			;;
		*)
			echo "❌ 未知指令: ${cmd}"
			cmd_help
			exit 1
			;;
	esac
}

main "$@"
