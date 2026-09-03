#!/usr/bin/env bash
# 每日全量备份调度循环：到达备份时刻执行备份，成功推 uptime-kuma 心跳，失败仅记日志（心跳缺失由 kuma 判定告警）
set -euo pipefail

STANZA="${PGBACKREST_STANZA:-main}"
BACKUP_HOUR="${PGBACKREST_BACKUP_HOUR:-3}"

push_heartbeat() {
	# uptime-kuma push 监控：心跳缺失即判定备份链路异常（覆盖调度器自身故障）
	[ -n "${UPTIME_KUMA_PUSH_URL:-}" ] || return 0
	curl -fsS "${UPTIME_KUMA_PUSH_URL}" > /dev/null || echo "uptime-kuma 心跳发送失败" >&2
}

seconds_until_next_run() {
	local now_epoch next_epoch
	now_epoch=$(date +%s)
	next_epoch=$(date -d "today ${BACKUP_HOUR}:00" +%s)
	if [ "${next_epoch}" -le "${now_epoch}" ]; then
		next_epoch=$(date -d "tomorrow ${BACKUP_HOUR}:00" +%s)
	fi
	echo $((next_epoch - now_epoch))
}

echo "pgBackRest 备份调度已启动：每日 ${BACKUP_HOUR}:00 执行全量备份 (stanza=${STANZA})"

while true; do
	sleep "$(seconds_until_next_run)"
	echo "[$(date '+%F %T')] 开始每日全量备份"
	if pgbackrest --stanza="${STANZA}" --type=full backup; then
		echo "[$(date '+%F %T')] 全量备份成功"
		push_heartbeat
	else
		echo "[$(date '+%F %T')] 全量备份失败" >&2
	fi
done
