#!/bin/bash
# 容器启动：生成 crontab 并通过 supercronic 前台运行
set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "restic 备份服务启动"
log "  仓库=${RESTIC_REPOSITORY}  源=${BACKUP_SOURCE}  cron=${CRON_SCHEDULE}"
log "  保留策略: daily=${RESTIC_KEEP_DAILY} weekly=${RESTIC_KEEP_WEEKLY} monthly=${RESTIC_KEEP_MONTHLY}"

# 生成 crontab 文件（supercronic 读取文件，不用 crontab -）
echo "${CRON_SCHEDULE} /scripts/backup.sh backup" > /etc/crontab

if [ "${RUN_ON_STARTUP:-false}" = "true" ]; then
	log "执行启动时备份..."
	/scripts/backup.sh backup
fi

exec supercronic /etc/crontab
