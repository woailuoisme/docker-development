#!/usr/bin/env bash
# ==============================================================================
# Fail2ban 容器服务运维管理脚本 (Fail2ban Container Management CLI)
# ==============================================================================
set -euo pipefail

CONTAINER_NAME="fail2ban"

# 检查容器运行状态
check_container() {
	if ! docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
		echo "❌ 错误: 容器 '${CONTAINER_NAME}' 未处于运行状态。"
		echo "💡 请先启动服务: docker compose up -d fail2ban"
		exit 1
	fi
}

# 操作系统平台检测提示
check_platform() {
	local os_name
	os_name="$(uname -s)"
	if [ "$os_name" = "Darwin" ]; then
		echo "⚠️  提示: 检测到当前操作系统为 macOS (Darwin)。"
		echo "ℹ️  Docker 在 macOS 上运行于轻量 Linux 虚拟机中，iptables 规则仅作用于 VM 网络栈，无法直接接管 macOS 宿主机端口与 PF 防火墙。"
		echo "ℹ️  如需全量生效并保护宿主机/VPS 流量，建议在生产 Linux 环境 (Debian/Ubuntu/CentOS) 下运行。"
		echo "----------------------------------------------------------------------"
	fi
}

# 调用容器内部 fail2ban-client
f2b_exec() {
	check_container
	docker exec -t "${CONTAINER_NAME}" fail2ban-client "$@"
}

# 显示帮助信息
show_help() {
	cat << 'EOF'
Fail2ban 容器服务运维管理工具

用法:
  ./manage.sh <command> [arguments...]

可用命令:
  status [jail]            查看 Fail2ban 服务状态或指定 Jail 的详细封禁状态
  banned                   汇总列出所有当前活跃 Jail 中已封禁的 IP 地址
  ban <jail> <ip>          手动将指定 IP 加入特定 Jail 的封禁黑名单
  unban <jail> <ip>        手动解除指定 Jail 中对某个 IP 的封禁
  unban-all <ip>           在所有已启用的 Jail 中全局解封某个 IP
  reload                   平滑重新加载 Fail2ban 配置文件与 Jails 规则
  ping                     测试 Fail2ban Server 守护进程的连通性
  client <args...>         直接向容器透传执行原始 fail2ban-client 命令行指令
  logs [lines]             实时查看 Fail2ban 容器的标准日志流 (默认最近 50 行)
  help                     显示本帮助信息

常用示例:
  ./manage.sh status
  ./manage.sh status caddy
  ./manage.sh banned
  ./manage.sh ban caddy 198.51.100.2
  ./manage.sh unban caddy 198.51.100.2
  ./manage.sh unban-all 198.51.100.2
  ./manage.sh reload
EOF
}

main() {
	local cmd="${1:-help}"

	case "$cmd" in
		status)
			check_platform
			if [ -n "${2:-}" ]; then
				f2b_exec status "$2"
			else
				f2b_exec status
			fi
			;;
		banned)
			check_platform
			check_container
			echo "🔍 正在检索所有活跃 Jail 的已封禁 IP..."
			local jails
			jails="$(docker exec "${CONTAINER_NAME}" fail2ban-client status 2> /dev/null | grep -i "Jail list" | sed -E 's/^[^:]+:[ \t]*//' | tr ',' ' ' || true)"
			if [ -z "${jails// /}" ]; then
				echo "ℹ️  当前没有正在运行的 Jail。"
				exit 0
			fi

			for j in $jails; do
				echo ""
				echo "=== Jail: [${j}] ==="
				docker exec "${CONTAINER_NAME}" fail2ban-client status "$j" | grep -E "(Currently banned|Total banned|Banned IP list)" || true
			done
			;;
		ban)
			if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
				echo "❌ 错误: 缺少参数。用法: ./manage.sh ban <jail> <ip>"
				exit 1
			fi
			f2b_exec set "$2" banip "$3"
			echo "✔ 已将 IP '$3' 加入 Jail '$2' 封禁黑名单。"
			;;
		unban)
			if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
				echo "❌ 错误: 缺少参数。用法: ./manage.sh unban <jail> <ip>"
				exit 1
			fi
			f2b_exec set "$2" unbanip "$3"
			echo "✔ 已从 Jail '$2' 解除对 IP '$3' 的封禁。"
			;;
		unban-all)
			if [ -z "${2:-}" ]; then
				echo "❌ 错误: 缺少参数。用法: ./manage.sh unban-all <ip>"
				exit 1
			fi
			f2b_exec unban "$2"
			echo "✔ 已在所有 Jail 中解封 IP '$2'。"
			;;
		reload)
			f2b_exec reload
			echo "✔ Fail2ban 配置已重新加载完毕。"
			;;
		ping)
			f2b_exec ping
			;;
		client)
			shift
			f2b_exec "$@"
			;;
		logs)
			local lines="${2:-50}"
			docker logs -f --tail "${lines}" "${CONTAINER_NAME}"
			;;
		help | --help | -h)
			show_help
			;;
		*)
			echo "❌ 未知命令: '$cmd'"
			echo "运行 './manage.sh help' 查看支持的命令选项。"
			exit 1
			;;
	esac
}

main "$@"
