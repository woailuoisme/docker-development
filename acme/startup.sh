#!/bin/sh
set -e

# 颜色定义
C_R="\033[31m" C_G="\033[32m" C_Y="\033[33m" C_B="\033[34m" C_C="\033[36m" C_0="\033[0m"

# 日志输出函数
log_msg() {
	printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} %s %s\n" "$1" "$2"
}
log_info() { log_msg "${C_B}[INFO]${C_0}" "$1"; }
log_success() { log_msg "${C_G}[SUCCESS]${C_0}" "$1"; }
log_warning() { log_msg "${C_Y}[WARNING]${C_0}" "$1"; }
log_error() { log_msg "${C_R}[ERROR]${C_0}" "$1"; }

# 降级到 crond 守护进程以保持容器存活，方便排查错误
fallback_to_cron() {
	log_warning "Falling back to crond daemon to keep container running. Please fix configuration and restart."
	exec crond -f
}

# 基础配置
DNS_PROVIDER=${DNS_PROVIDER:-cloudflare} # 可选值: aliyun, cloudflare
DOMAIN=${DOMAIN:-haoxiaoguai.xyz}
EMAIL=${EMAIL:-admin@haoxiaoguai.xyz}
MAX_RETRIES=${MAX_RETRIES:-1} # 默认重试1次
ACME_DEBUG=${ACME_DEBUG:-0}   # 调试模式: 0=off, 1=basic, 2=full

# 打印脱敏的环境变量，防止敏感信息泄露
log_env_masked() {
	if [ -n "$2" ]; then
		log_info "$1: ********"
	else
		log_info "$1: [NOT SET]"
	fi
}

log_info "---------------- Environment Variables ----------------"
log_info "DNS_PROVIDER: $DNS_PROVIDER"
log_info "DOMAIN: $DOMAIN"
log_info "EMAIL: $EMAIL"
log_info "MAX_RETRIES: $MAX_RETRIES"
log_info "ACME_DEBUG: $ACME_DEBUG"
log_env_masked "CLOUDFLARE_API_TOKEN" "$CLOUDFLARE_API_TOKEN"
log_env_masked "ALIYUN_ACCESS_KEY_ID" "$ALIYUN_ACCESS_KEY_ID"
log_env_masked "ALIYUN_ACCESS_KEY_SECRET" "$ALIYUN_ACCESS_KEY_SECRET"
log_info "-------------------------------------------------------"

# 证书输出目录 (映射到 Nginx 的 SSL 目录)
SSL_OUTPUT="/ssl/live/${DOMAIN}"

# 清理指定域名配置和证书文件
cleanup_domain() {
	log_warning "Cleaning up domain config and directory for $DOMAIN..."
	acme.sh --remove -d "$DOMAIN" > /dev/null 2>&1 || true
	rm -rf "/acme.sh/${DOMAIN}_ecc" "/acme.sh/${DOMAIN}" || true
}

# 配置 DNS 凭据并检查必要变量
setup_credentials() {
	case "$DNS_PROVIDER" in
		"cloudflare")
			if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
				log_error "Error: CLOUDFLARE_API_TOKEN is not set in .env or environment variables!"
				fallback_to_cron
			fi
			export CF_Token="$CLOUDFLARE_API_TOKEN"
			export DNS_TYPE="dns_cf"
			;;
		"aliyun")
			if [ -z "$ALIYUN_ACCESS_KEY_ID" ] || [ -z "$ALIYUN_ACCESS_KEY_SECRET" ]; then
				log_error "Error: ALIYUN_ACCESS_KEY_ID or ALIYUN_ACCESS_KEY_SECRET is not set in .env or environment variables!"
				fallback_to_cron
			fi
			export Ali_Key="$ALIYUN_ACCESS_KEY_ID"
			export Ali_Secret="$ALIYUN_ACCESS_KEY_SECRET"
			export DNS_TYPE="dns_ali"
			;;
		*)
			log_error "Error: Unknown DNS provider: $DNS_PROVIDER"
			fallback_to_cron
			;;
	esac
}

# 注册账号并进行永久配置
if [ ! -f "/acme.sh/account.conf" ]; then
	log_info "Initializing acme.sh configuration..."

	# 1. 设置默认 CA 为 letsencrypt 并注册账号
	log_info "Setting default CA to letsencrypt and registering account with email $EMAIL..."
	acme.sh --set-default-ca --server letsencrypt
	acme.sh --register-account -m "$EMAIL" --server letsencrypt

	# 2. 设置 DNS 永久配置
	setup_credentials
	log_info "Setting persistent DNS configuration for $DOMAIN using $DNS_TYPE..."
	acme.sh --set-dns -d "$DNS_TYPE" \
		--yes-I-know-dns-manual-mode-enough-go-ahead-please \
		--force
fi

# 单次尝试申请与安装
try_issue_and_install() {
	# 1. 检查证书是否已管理
	is_managed=0
	acme.sh --list | grep -q "$DOMAIN" && is_managed=1

	# 如果已管理但证书文件缺失，则强制清理以重新申请
	if [ "$is_managed" -eq 1 ]; then
		if [ ! -f "/acme.sh/${DOMAIN}_ecc/fullchain.cer" ] && [ ! -f "/acme.sh/${DOMAIN}/fullchain.cer" ]; then
			log_warning "Certificate managed but files missing. Force removing..."
			cleanup_domain
			is_managed=0
		else
			log_success "Certificate for $DOMAIN already managed by acme.sh."
		fi
	fi

	# 如果未管理，则开始申请
	if [ "$is_managed" -eq 0 ]; then
		log_info "Issuing certificate for $DOMAIN via $DNS_PROVIDER..."

		# 根据 ACME_DEBUG 级别匹配调试参数
		DEBUG_OPT=""
		case "$ACME_DEBUG" in
			1) DEBUG_OPT="--debug" ;;
			2) DEBUG_OPT="--debug 2" ;;
		esac

		log_info "Executing: acme.sh --issue --dns $DNS_TYPE -d $DOMAIN -d *.$DOMAIN --server letsencrypt $DEBUG_OPT"

		# 利用 if 条件执行，即使失败也不会触发 set -e 导致脚本退出
		if ! acme.sh --issue --dns "$DNS_TYPE" -d "$DOMAIN" -d "*.$DOMAIN" --server letsencrypt $DEBUG_OPT; then
			log_error "Certificate issuance failed."
			return 1
		fi
	fi

	# 2. 安装证书到指定输出目录
	mkdir -p "$SSL_OUTPUT"
	log_info "Installing certificate to $SSL_OUTPUT..."

	# 利用 if 条件执行，保证安装失败时返回错误码而不直接终止脚本
	if ! acme.sh --install-cert -d "$DOMAIN" \
		--key-file "$SSL_OUTPUT/privkey.pem" \
		--fullchain-file "$SSL_OUTPUT/fullchain.pem" \
		--reloadcmd "echo 'Certificate updated.'"; then
		log_error "Certificate installation failed."
		return 1
	fi

	return 0
}

# 带重试机制的主逻辑
issue_and_install_with_retry() {
	setup_credentials

	count=1
	while [ "$count" -le "$MAX_RETRIES" ]; do
		log_info "Attempt $count of $MAX_RETRIES..."

		if try_issue_and_install; then
			log_success "Certificate issued and installed successfully!"
			return 0
		fi

		log_warning "Attempt $count failed."

		if [ "$count" -lt "$MAX_RETRIES" ]; then
			cleanup_domain
			log_warning "Retrying in 10s..."
			sleep 10
		fi

		count=$((count + 1))
	done

	log_error "All $MAX_RETRIES attempts failed."
	log_warning "Falling back to crond daemon to keep container running. Check logs for details."
}

# 执行核心逻辑
issue_and_install_with_retry

# 启动 Crond 守护进程 (前台运行)
log_info "Starting crond daemon..."
exec crond -f
