#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# goacme/lego v5 现代化证书自动化管理守护脚本
# 遵循 Lego v5 设计哲学：统一 run 生命周期 + 原生 --deploy-hook 驱动
# ==============================================================================

# ANSI 终端色彩与结构化日志
C_R="\033[31m" C_G="\033[32m" C_Y="\033[33m" C_B="\033[34m" C_C="\033[36m" C_0="\033[0m"

log_msg() { printf "${C_C}[%s]${C_0} %b %b\n" "$(date '+%Y-%m-%d %H:%M:%S %z')" "$1" "$2"; }
log_info() { log_msg "${C_B}[INFO]${C_0}" "$1"; }
log_success() { log_msg "${C_G}[SUCCESS]${C_0}" "$1"; }
log_warning() { log_msg "${C_Y}[WARNING]${C_0}" "$1"; }
log_error() { log_msg "${C_R}[ERROR]${C_0}" "$1"; }

# 基础参数配置与默认值
DOMAIN="${SITE_ADDRESS:-${DOMAIN:-example.com}}"
EMAIL="${EMAIL:-admin@${DOMAIN}}"
DNS_PROVIDER="${DNS_PROVIDER:-cloudflare}"
LEGO_CA_STAGING="${LEGO_CA_STAGING:-false}"
LEGO_KEY_TYPE="${LEGO_KEY_TYPE:-ec256}"
LEGO_RENEW_INTERVAL="${LEGO_RENEW_INTERVAL:-43200}"
RELOAD_CONTAINER="${RELOAD_CONTAINER:-nginx}"
LEGO_SERVER="${LEGO_SERVER:-}"
LEGO_PATH="${LEGO_PATH:-/.lego}"

# 核心证书路径定义 (单一事实来源)
CERT_DIR="${LEGO_PATH}/certificates"
CERT_FILE="${CERT_DIR}/${DOMAIN}.crt"
KEY_FILE="${CERT_DIR}/${DOMAIN}.key"
ISSUER_FILE="${CERT_DIR}/${DOMAIN}.issuer.crt"
SSL_OUTPUT="/ssl/live/${DOMAIN}"
SCRIPT_PATH="${BASH_SOURCE[0]}"

# 敏感凭证脱敏显示
log_env_masked() {
	local var="$1"
	local val="${!var-}"
	log_info "${var}: $([ -n "${val}" ] && echo "********" || echo "[NOT SET]")"
}

# 1. 证书导出至标准路径
export_certificates() {
	local cert_src="${LEGO_CERT_PATH:-${CERT_FILE}}"
	local key_src="${LEGO_CERT_KEY_PATH:-${KEY_FILE}}"

	if [ ! -f "${cert_src}" ] || [ ! -f "${key_src}" ]; then
		log_error "证书源文件不存在: ${cert_src}"
		return 1
	fi

	mkdir -p "${SSL_OUTPUT}"
	log_info "同步证书至标准输出目录: ${SSL_OUTPUT}..."
	cp -f "${cert_src}" "${SSL_OUTPUT}/fullchain.pem"
	cp -f "${key_src}" "${SSL_OUTPUT}/privkey.pem"
	[ -f "${ISSUER_FILE}" ] && cp -f "${ISSUER_FILE}" "${SSL_OUTPUT}/chain.pem"
	chmod 600 "${SSL_OUTPUT}/privkey.pem" 2> /dev/null || true
	chmod 644 "${SSL_OUTPUT}/fullchain.pem" 2> /dev/null || true
	log_success "标准证书已就绪: ${SSL_OUTPUT}/{fullchain.pem,privkey.pem}"
}

# 2. 通过 Docker Socket 重载下游容器
reload_downstream() {
	case "${RELOAD_CONTAINER}" in "" | none | false) return 0 ;; esac
	if [ ! -S /var/run/docker.sock ]; then
		log_warning "/var/run/docker.sock 未挂载，跳过下游容器重载。"
		return 0
	fi

	log_info "通过 Docker Socket 向容器 '${RELOAD_CONTAINER}' 发送 HUP 信号..."
	local http_code
	http_code=$(curl -s -o /dev/null -w "%{http_code}" --unix-socket /var/run/docker.sock -X POST "http://localhost/containers/${RELOAD_CONTAINER}/kill?signal=HUP" || echo "000")

	case "${http_code}" in
		204) log_success "已成功向容器 '${RELOAD_CONTAINER}' 发送重载信号 (HTTP 204)。" ;;
		404) log_warning "下游容器 '${RELOAD_CONTAINER}' 未找到 (HTTP 404)，请核对容器名称。" ;;
		*) log_warning "重载请求返回异常 HTTP 状态码: ${http_code}" ;;
	esac
}

# 3. Lego v5 原生 --deploy-hook 回调入口
handle_deploy_hook() {
	log_info "================ Lego v5 Deploy Hook Triggered ================"
	log_info "Target Domain: ${LEGO_CERT_DOMAIN:-${DOMAIN}}"
	export_certificates
	reload_downstream
	log_info "==============================================================="
	exit 0
}

# 若作为 --deploy-hook 调用，直接处理部署并退出
if [ "${1:-}" = "--deploy-hook" ]; then
	handle_deploy_hook
fi

# 4. 提供商别名与多兼容凭据归一化
normalize_credentials() {
	case "${DNS_PROVIDER}" in
		aliyun | alidns)
			DNS_PROVIDER="alidns"
			export ALICLOUD_ACCESS_KEY="${ALICLOUD_ACCESS_KEY:-${ALIYUN_ACCESS_KEY_ID:-${ALI_ACCESS_KEY:-}}}"
			export ALICLOUD_SECRET_KEY="${ALICLOUD_SECRET_KEY:-${ALIYUN_ACCESS_KEY_SECRET:-${ALI_ACCESS_KEY_SECRET:-}}}"
			;;
		cloudflare)
			export CF_DNS_API_TOKEN="${CF_DNS_API_TOKEN:-${CF_API_TOKEN:-${CLOUDFLARE_API_TOKEN:-${DNS_CLOUDFLARE_API_TOKEN:-}}}}"
			;;
		tencentcloud)
			export TENCENTCLOUD_SECRET_ID="${TENCENTCLOUD_SECRET_ID:-${TENCENT_SECRET_ID:-}}"
			export TENCENTCLOUD_SECRET_KEY="${TENCENTCLOUD_SECRET_KEY:-${TENCENT_SECRET_KEY:-}}"
			;;
	esac
}

# 5. 校验提供商凭据完整性
validate_credentials() {
	case "${DNS_PROVIDER}" in
		cloudflare)
			[ -n "${CF_DNS_API_TOKEN:-}" ] || { [ -n "${CLOUDFLARE_EMAIL:-}" ] && [ -n "${CLOUDFLARE_API_KEY:-}" ]; } || {
				log_error "Cloudflare 凭据缺失！请设置 CF_DNS_API_TOKEN 或 CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY"
				return 1
			}
			;;
		alidns)
			[ -n "${ALICLOUD_ACCESS_KEY:-}" ] && [ -n "${ALICLOUD_SECRET_KEY:-}" ] || {
				log_error "阿里云 DNS 凭据缺失！请设置 ALICLOUD_ACCESS_KEY 与 ALICLOUD_SECRET_KEY"
				return 1
			}
			;;
		tencentcloud)
			[ -n "${TENCENTCLOUD_SECRET_ID:-}" ] && [ -n "${TENCENTCLOUD_SECRET_KEY:-}" ] || {
				log_error "腾讯云 DNS 凭据缺失！请设置 TENCENTCLOUD_SECRET_ID 与 TENCENTCLOUD_SECRET_KEY"
				return 1
			}
			;;
		*)
			log_info "使用 DNS 提供商: ${DNS_PROVIDER} (需确保已注入 Lego 原生认证环境变量)"
			;;
	esac
	return 0
}

# 6. 打印当前环境概览
print_summary() {
	log_info "================ Lego ACME Service Starting (Lego v5 Engine) ================"
	log_info "Target Domain        : ${DOMAIN} (SAN: *.${DOMAIN})"
	log_info "Notification Email   : ${EMAIL}"
	log_info "DNS-01 Provider      : ${DNS_PROVIDER}"
	log_info "Key Type / CA Staging: ${LEGO_KEY_TYPE} / ${LEGO_CA_STAGING}"
	log_info "Renewal / Reload     : ${LEGO_RENEW_INTERVAL}s / ${RELOAD_CONTAINER}"
	log_info "Standard SSL Output  : ${SSL_OUTPUT}"
	for var in CF_DNS_API_TOKEN ALICLOUD_ACCESS_KEY ALICLOUD_SECRET_KEY TENCENTCLOUD_SECRET_ID TENCENTCLOUD_SECRET_KEY; do
		log_env_masked "${var}"
	done
	log_info "============================================================================"
}

# 7. Lego v5 统一指令包装器 (依托 --deploy-hook 实现事件驱动同步)
run_lego_cycle() {
	local -a args=(
		run
		--accept-tos
		--path "${LEGO_PATH}"
		--email "${EMAIL}"
		--dns "${DNS_PROVIDER}"
		--key-type "${LEGO_KEY_TYPE}"
		-d "${DOMAIN}"
		-d "*.${DOMAIN}"
		--deploy-hook "${SCRIPT_PATH} --deploy-hook"
	)

	if [ -n "${LEGO_SERVER}" ]; then
		args+=(--server "${LEGO_SERVER}")
	elif [ "${LEGO_CA_STAGING}" = "true" ] || [ "${LEGO_CA_STAGING}" = "1" ]; then
		log_warning "Running in ACME Staging mode (Let's Encrypt Staging Directory)"
		args+=(--server "https://acme-staging-v02.api.letsencrypt.org/directory")
	fi

	log_info "执行 Lego v5 run 周期检测 (未签发则申请，已有效则检查，临期则自动续订)..."
	lego "${args[@]}"
}

# 优雅退出信号捕获
trap 'log_info "收到终止信号，正在平滑退出 Lego 守护进程..."; exit 0' SIGTERM SIGINT

# 8. 主进程启动
normalize_credentials
print_summary

if ! validate_credentials; then
	log_warning "凭据完整性检查未通过，守护进程将持续运行以防止容器反复重启崩溃。"
else
	# 预检查：若持久化存储已有证书但标准输出路径缺失，做一次冷启动同步
	if [ -f "${CERT_FILE}" ] && [ ! -f "${SSL_OUTPUT}/fullchain.pem" ]; then
		log_info "检测到历史持久化证书，执行初始标准目录同步..."
		export_certificates || true
	fi

	# 执行首轮申请/状态确认
	if ! run_lego_cycle; then
		log_warning "首轮 Lego 检测未能成功获取证书，将进入守护循环周期重试。"
	fi
fi

# 9. 常驻守护续签循环 (纯粹依托 Lego v5 run 与 --deploy-hook)
log_info "进入周期守护循环 (每隔 ${LEGO_RENEW_INTERVAL}s 触发一次 Lego run 检测)..."
while true; do
	sleep "${LEGO_RENEW_INTERVAL}" &
	wait $!

	log_info "触发计划任务：Lego v5 证书周期自检..."
	run_lego_cycle || log_warning "Lego 周期检测返回非零状态码，将在下一轮重试。"
done
