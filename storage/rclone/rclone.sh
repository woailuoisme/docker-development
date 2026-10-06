#!/usr/bin/env bash
# 优化简化版 rclone 容器化工具入口

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="${script_dir}/docker-compose.yml"

subcommand="${1:-}"
if [[ ! "$subcommand" =~ ^(ls|delete|copy|sync)$ ]]; then
	echo "Usage: $(basename "$0") {ls|delete|copy|sync} [args...]" >&2
	exit 1
fi
shift

# 参数校验：ls/delete 需要至少 1 个参数，copy/sync 需要至少 2 个参数
if { [[ "$subcommand" =~ ^(ls|delete)$ ]] && [ "$#" -lt 1 ]; } \
	|| { [[ "$subcommand" =~ ^(copy|sync)$ ]] && [ "$#" -lt 2 ]; }; then
	echo "Error: Insufficient arguments for subcommand '${subcommand}'" >&2
	exit 1
fi

# 核心设计：仅在发生文件同步/复制时才挂载当前工作目录，
# 从而避免 ls 和 delete 在空目录下运行时不必要的挂载开销。
extra_args=()
if [[ "$subcommand" =~ ^(copy|sync)$ ]]; then
	extra_args=(-v "${PWD}:/work" -w /work)
fi

exec docker compose -f "${compose_file}" run --rm "${extra_args[@]}" rclone --config /config/rclone.conf "$subcommand" "$@"
