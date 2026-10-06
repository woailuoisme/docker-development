#!/usr/bin/env bash
# ==============================================================================
# VictoriaMetrics 生态运维辅助脚本 (victoria-metrics / victoria-logs / vmalert)
# ==============================================================================
# 覆盖四件事：告警规则单元测试、时序库备份、恢复演练与灾难恢复、日志交互查询。
# 由 justfile 的同名配方调用（just vm-alert-test / vm-backup-now / ...）。
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 载入仓库环境变量（独立执行时也要能拿到 DATA_PATH）
if [ -f "${ROOT_DIR}/.env" ]; then
	set -a
	# shellcheck disable=SC1091
	. "${ROOT_DIR}/.env"
	set +a
fi

# 路径统一带尾斜杠：兼容 .env 里写 "./data/"、绝对路径、带或不带尾斜杠三种写法
DATA_DIR="${DATA_PATH:-${ROOT_DIR}/data/}"
DATA_DIR="${DATA_DIR%/}/"
CONFIG_DIR="${ROOT_DIR}/"

# 与 observability/ 下各 compose 保持一致的版本，改名时同步此处
VM_VERSION="v1.151.0"
VL_VERSION="v1.52.0"
NETWORK_NAME="${VM_NETWORK:-backend}"

# 各子命令用到的路径集中命名，避免同一串拼接散落各处
VM_DATA_DIR="${DATA_DIR}victoria"
VM_BACKUP_DIR="${DATA_DIR}victoria-backup"
BACKUP_LATEST="${VM_BACKUP_DIR}/latest"
RESTORE_TEST_DIR="${DATA_DIR}victoria-restore-test"
RESTORE_TEST_CONTAINER="vm-restore-test"
VLOGSCLI_HISTORY_DIR="${DATA_DIR}vlogscli"

print_usage() {
	cat << EOF
Usage: $(basename "$0") <command>

Commands:
  alert-test            运行 vmalert 告警规则单元测试 (vmalert-tool，合成时序断言告警行为)
  backup-now            手动触发一次 VictoriaMetrics 时序库备份 (快照 + 增量上传)
  backup-restore-test   恢复演练：恢复到隔离目录并用临时实例验证，不触碰生产数据
  restore               灾难恢复：用最新备份重建生产时序库 (需人工确认，旧数据改名留存)
  logs-query            交互式查询 VictoriaLogs 日志 (vlogscli，退出输入 q)
  scrape-secrets        从 .env 生成 vmagent 的抓取鉴权文件 (garage / meilisearch)
  help                  显示此帮助信息

Examples:
  ./scripts/victoria.sh alert-test
  ./scripts/victoria.sh backup-now
  ./scripts/victoria.sh backup-restore-test
  ./scripts/victoria.sh restore
  ./scripts/victoria.sh logs-query
  ./scripts/victoria.sh scrape-secrets
EOF
}

# 恢复演练的收尾：无论成功失败都清掉临时容器与隔离目录
restore_test_cleanup() {
	docker stop "${RESTORE_TEST_CONTAINER}" > /dev/null 2>&1 || true
	rm -rf "${RESTORE_TEST_DIR}"
}

# 查询一个实例的 count(up)：容器内自带 wget，避免依赖宿主机工具链
query_up_count() {
	local container="$1"
	docker exec "${container}" wget -qO- \
		"http://127.0.0.1:8428/api/v1/query?query=count(up)" 2> /dev/null \
		| grep -o '"value":\[[^]]*\]' || echo "(查询无结果)"
}

# 备份缺失时给出可执行的下一步，而不是让 vmrestore 抛一段路径错误
require_backup() {
	if [ ! -d "${BACKUP_LATEST}" ]; then
		echo "❌ 未发现备份 ${BACKUP_LATEST}，请先执行: $(basename "$0") backup-now"
		exit 1
	fi
}

# 把备份恢复到指定目录：演练与灾难恢复共用同一段调用，只有目标目录不同
run_vmrestore() {
	local target_dir="$1"
	docker run --rm \
		-v "${VM_BACKUP_DIR}:/backup:ro" \
		-v "${target_dir}:/storage" \
		"victoriametrics/vmrestore:${VM_VERSION}" \
		-src=fs:///backup/latest \
		-storageDataPath=/storage
}

# 写入一个抓取鉴权文件：即使值为空也要落盘，否则 vmagent 读取 bearer_token_file 会因文件缺失而拒绝整份配置
write_scrape_secret() {
	local path="$1"
	local value="$2"
	printf '%s' "${value}" > "${path}"
	chmod 600 "${path}"
	if [ -z "${value}" ]; then
		echo "⚠ ${path} 为空（.env 未设置对应变量）：该抓取任务会 401，但不会阻塞 vmagent"
	else
		echo "✔ 已写入 ${path}"
	fi
}

cmd_alert_test() {
	echo "→ 运行 vmalert 告警规则单元测试..."
	docker run --rm \
		-v "${CONFIG_DIR}observability/victoria-alert:/tests:ro" \
		-w /tests \
		"victoriametrics/vmalert-tool:${VM_VERSION}" \
		unittest -files=alerts_test.yml
}

cmd_backup_now() {
	mkdir -p "${VM_BACKUP_DIR}"
	echo "→ 向 VictoriaMetrics 申请瞬时快照并备份到 ${BACKUP_LATEST} ..."
	docker run --rm --network "${NETWORK_NAME}" \
		-v "${VM_DATA_DIR}:/storage:ro" \
		-v "${VM_BACKUP_DIR}:/backup" \
		"victoriametrics/vmbackup:${VM_VERSION}" \
		-storageDataPath=/storage \
		-snapshot.createURL=http://victoria-metrics:8428/snapshot/create \
		-dst=fs:///backup/latest
	echo "✔ 备份完成 (vmbackup 已自动删除临时快照)"
}

cmd_backup_restore_test() {
	require_backup

	trap restore_test_cleanup EXIT
	rm -rf "${RESTORE_TEST_DIR}"
	mkdir -p "${RESTORE_TEST_DIR}"

	echo "→ 从 ${BACKUP_LATEST} 恢复到隔离目录..."
	run_vmrestore "${RESTORE_TEST_DIR}"

	echo "→ 启动临时 VictoriaMetrics 验证恢复数据..."
	docker run --rm -d --name "${RESTORE_TEST_CONTAINER}" \
		-v "${RESTORE_TEST_DIR}:/storage" \
		"victoriametrics/victoria-metrics:${VM_VERSION}" \
		--storageDataPath=/storage \
		--httpListenAddr=:8428 > /dev/null
	sleep 7

	echo "   恢复实例 count(up) = $(query_up_count "${RESTORE_TEST_CONTAINER}")"
	echo "   生产实例 count(up) = $(query_up_count victoria-metrics)"
	echo "✔ 恢复演练通过：备份数据完整可用"
}

cmd_restore() {
	require_backup

	echo "⚠ 即将用 ${BACKUP_LATEST} 重建 ${VM_DATA_DIR}"
	echo "  旧数据会改名保留为 victoria.bak.<时间戳>，可人工回滚。"
	read -r -p "确认继续？输入 yes: " REPLY
	if [ "${REPLY}" != "yes" ]; then
		echo "已取消"
		exit 1
	fi

	echo "→ 停止 victoria-metrics (避免恢复期间继续写入)..."
	docker compose stop victoria-metrics

	local stamp
	stamp="$(date +%Y%m%d%H%M%S)"
	echo "→ 旧数据改名留存为 victoria.bak.${stamp} ..."
	mv "${VM_DATA_DIR}" "${VM_DATA_DIR}.bak.${stamp}"
	mkdir -p "${VM_DATA_DIR}"

	echo "→ 从最新备份恢复..."
	run_vmrestore "${VM_DATA_DIR}"

	echo "→ 重新启动 victoria-metrics..."
	docker compose start victoria-metrics
	echo "✔ 恢复完成；确认无误后可删除 ${VM_DATA_DIR}.bak.${stamp}"
}

cmd_logs_query() {
	mkdir -p "${VLOGSCLI_HISTORY_DIR}"
	docker run --rm -it --network "${NETWORK_NAME}" \
		-v "${VLOGSCLI_HISTORY_DIR}:/history" \
		"victoriametrics/vlogscli:${VL_VERSION}" \
		-datasource.url=http://victoria-logs:9428/select/logsql/query \
		-historyFile=/history/history
}

cmd_scrape_secrets() {
	local secrets_dir="${DATA_DIR}victoria-agent/secrets"
	mkdir -p "${secrets_dir}"
	echo "→ 从 .env 生成抓取鉴权文件到 ${secrets_dir} ..."
	write_scrape_secret "${secrets_dir}/garage_metrics_token" "${GARAGE_METRICS_TOKEN:-}"
	write_scrape_secret "${secrets_dir}/meili_master_key" "${MEILI_MASTER_KEY:-}"
}

cmd="${1:-help}"
# 无参数时 shift 返回非零，配合 set -e 会直接退出整个脚本
shift || true

case "${cmd}" in
	alert-test)
		cmd_alert_test
		;;
	backup-now)
		cmd_backup_now
		;;
	backup-restore-test)
		cmd_backup_restore_test
		;;
	restore)
		cmd_restore
		;;
	logs-query)
		cmd_logs_query
		;;
	scrape-secrets)
		cmd_scrape_secrets
		;;
	help | --help | -h)
		print_usage
		;;
	*)
		echo "❌ 未知命令: ${cmd}"
		echo
		print_usage
		exit 1
		;;
esac
