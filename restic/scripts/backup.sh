#!/bin/bash
# restic backup / restore 脚本
# 用法:
#   backup.sh           — 执行备份（默认）
#   backup.sh restore   — 恢复最新快照到 RESTORE_TARGET
#   backup.sh restore <snapshot-id>  — 恢复指定快照
set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

init_repo() {
	if ! restic snapshots --quiet > /dev/null 2>&1; then
		log "初始化仓库: ${RESTIC_REPOSITORY}"
		restic init
	fi
}

do_backup() {
	init_repo
	log "开始备份: ${BACKUP_SOURCE}"
	# shellcheck disable=SC2086
	restic backup ${BACKUP_SOURCE} --verbose
	log "清理旧快照 (daily=${RESTIC_KEEP_DAILY} weekly=${RESTIC_KEEP_WEEKLY} monthly=${RESTIC_KEEP_MONTHLY})"
	restic forget \
		--keep-daily "${RESTIC_KEEP_DAILY}" \
		--keep-weekly "${RESTIC_KEEP_WEEKLY}" \
		--keep-monthly "${RESTIC_KEEP_MONTHLY}" \
		--prune
	log "备份完成"
}

do_restore() {
	local snapshot="${1:-latest}"
	local target="${RESTORE_TARGET:-/restore}"
	init_repo
	log "恢复快照 [${snapshot}] → ${target}"
	mkdir -p "${target}"
	restic restore "${snapshot}" --target "${target}" --verbose
	log "恢复完成: ${target}"
}

case "${1:-backup}" in
	backup) do_backup ;;
	restore) do_restore "${2:-latest}" ;;
	*) echo "用法: $0 [backup|restore [snapshot-id]]" && exit 1 ;;
esac
