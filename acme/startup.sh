#!/bin/sh
set -e

# 颜色定义
C_R="\033[31m" C_G="\033[32m" C_Y="\033[33m" C_B="\033[34m" C_C="\033[36m" C_1="\033[1m" C_0="\033[0m"

# 日志函数
log_info()    { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_B}[INFO]${C_0} %s\n" "$1"; }
log_success() { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_G}[SUCCESS]${C_0} %s\n" "$1"; }
log_warning() { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_Y}[WARNING]${C_0} %s\n" "$1"; }
log_error()   { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_R}[ERROR]${C_0} %s\n" "$1"; }


# 基础配置
DNS_PROVIDER=${DNS_PROVIDER:-aliyun}  # 可选值: aliyun, cloudflare
DOMAIN=${DOMAIN:-haoxiaoguai.xyz}
EMAIL=${EMAIL:-admin@haoxiaoguai.xyz}
MAX_RETRIES=${MAX_RETRIES:-1}  # 默认重试1次
ACME_DEBUG=${ACME_DEBUG:-0}    # 调试模式: 0=off, 1=basic, 2=full

# 打印环境变量 (Debug) - 敏感信息脱敏
log_info "---------------- Environment Variables ----------------"
log_info "DNS_PROVIDER: $DNS_PROVIDER"
log_info "DOMAIN: $DOMAIN"
log_info "EMAIL: $EMAIL"
log_info "MAX_RETRIES: $MAX_RETRIES"
log_info "ACME_DEBUG: $ACME_DEBUG"
[ -n "$CLOUDFLARE_API_TOKEN" ] && log_info "CLOUDFLARE_API_TOKEN: ********" || log_info "CLOUDFLARE_API_TOKEN: [NOT SET]"
[ -n "$ALIYUN_ACCESS_KEY_ID" ] && log_info "ALIYUN_ACCESS_KEY_ID: ********" || log_info "ALIYUN_ACCESS_KEY_ID: [NOT SET]"
[ -n "$ALIYUN_ACCESS_KEY_SECRET" ] && log_info "ALIYUN_ACCESS_KEY_SECRET: ********" || log_info "ALIYUN_ACCESS_KEY_SECRET: [NOT SET]"
log_info "-------------------------------------------------------"

# 证书输出目录 (映射到 Nginx 的 SSL 目录)
# 容器内路径: /ssl/live/example.com/
SSL_OUTPUT="/ssl/live/${DOMAIN}"

# 配置 DNS 凭据并检查必要变量
setup_credentials() {
    case "$DNS_PROVIDER" in
        "cloudflare")
            if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
                log_error "Error: CLOUDFLARE_API_TOKEN is not set in .env or environment variables!"
                log_warning "Falling back to crond daemon to keep container running. Please fix configuration and restart."
                exec crond -f
            fi
            export CF_Token="$CLOUDFLARE_API_TOKEN"
            export DNS_TYPE="dns_cf"
            ;;
        "aliyun")
            if [ -z "$ALIYUN_ACCESS_KEY_ID" ] || [ -z "$ALIYUN_ACCESS_KEY_SECRET" ]; then
                log_error "Error: ALIYUN_ACCESS_KEY_ID or ALIYUN_ACCESS_KEY_SECRET is not set in .env or environment variables!"
                log_warning "Falling back to crond daemon to keep container running. Please fix configuration and restart."
                exec crond -f
            fi
            export Ali_Key="$ALIYUN_ACCESS_KEY_ID"
            export Ali_Secret="$ALIYUN_ACCESS_KEY_SECRET"
            export DNS_TYPE="dns_ali"
            ;;
        *)
            log_error "Error: Unknown DNS provider: $DNS_PROVIDER"
            log_warning "Falling back to crond daemon to keep container running. Please fix configuration and restart."
            exec crond -f
            ;;
    esac
}

# 注册账号并进行永久配置
if [ ! -f "/acme.sh/account.conf" ]; then
    log_info "Initializing acme.sh configuration..."
    
    # 0. 尝试升级 acme.sh (确保功能完整)
    log_info "Upgrading acme.sh to latest version..."
    acme.sh --upgrade --auto-upgrade 0 || log_warning "Upgrade failed, continuing with current version."

    # 1. 设置默认 CA 为 letsencrypt 并注册账号
    log_info "Setting default CA to letsencrypt and registering account with email $EMAIL..."
    acme.sh --set-default-ca --server letsencrypt
    acme.sh --register-account -m "$EMAIL" --server letsencrypt
    
    # 2. 设置 DNS 永久配置
    setup_credentials
    log_info "Setting persistent DNS configuration for $DOMAIN using $DNS_TYPE..."
    # 使用用户指南建议的参数强化配置
    acme.sh --set-dns -d "$DNS_TYPE" \
        --yes-I-know-dns-manual-mode-enough-go-ahead-please \
        --force
fi

# 单次尝试申请与安装
try_issue_and_install() {
    # 1. 初始检查与申请
    # 如果证书已管理但文件缺失，强制清理
    if acme.sh --list | grep -q "$DOMAIN"; then
        if [ ! -f "/acme.sh/${DOMAIN}_ecc/fullchain.cer" ] && [ ! -f "/acme.sh/${DOMAIN}/fullchain.cer" ]; then
             log_warning "Certificate managed but files missing. Force removing..."
             acme.sh --remove -d "$DOMAIN"
             rm -rf "/acme.sh/${DOMAIN}_ecc" "/acme.sh/${DOMAIN}"
        else
             log_success "Certificate for $DOMAIN already managed by acme.sh."
        fi
    fi

    # 如果证书未被管理（或已被清理），则申请
    if ! acme.sh --list | grep -q "$DOMAIN"; then
        log_info "Issuing certificate for $DOMAIN via $DNS_PROVIDER..."
        
        # 准备调试参数
        DEBUG_OPT=""
        if [ "$ACME_DEBUG" -eq 1 ]; then
            DEBUG_OPT="--debug"
        elif [ "$ACME_DEBUG" -eq 2 ]; then
            DEBUG_OPT="--debug 2"
        fi

        # 打印即将执行的命令 (Debug)
        log_info "Executing: acme.sh --issue --dns $DNS_TYPE -d $DOMAIN -d *.$DOMAIN --server letsencrypt $DEBUG_OPT"

        # set +e 允许失败以便在主循环中处理
        set +e
        acme.sh --issue --dns "$DNS_TYPE" -d "$DOMAIN" -d "*.$DOMAIN" --server letsencrypt $DEBUG_OPT
        issue_code=$?
        set -e
        
        if [ $issue_code -ne 0 ]; then
            log_error "Issue failed with code $issue_code"
            return 1
        fi
    fi

    # 2. 安装证书
    mkdir -p "$SSL_OUTPUT"
    log_info "Installing certificate to $SSL_OUTPUT..."
    
    set +e
    acme.sh --install-cert -d "$DOMAIN" \
        --key-file       "$SSL_OUTPUT/privkey.pem"  \
        --fullchain-file "$SSL_OUTPUT/fullchain.pem" \
        --reloadcmd      "echo 'Certificate updated.'"
    local install_code=$?
    set -e
    
    if [ $install_code -ne 0 ]; then
        log_error "Install failed with code $install_code"
        return 1
    fi
    
    return 0
}

# 带重试机制的主逻辑
issue_and_install_with_retry() {
    setup_credentials
    
    count=1
    while [ $count -le $MAX_RETRIES ]; do
        log_info "Attempt $count of $MAX_RETRIES..."
        
        if try_issue_and_install; then
            log_success "Certificate issued and installed successfully!"
            return 0
        fi
        
        log_warning "Attempt $count failed."
        
        if [ $count -lt $MAX_RETRIES ]; then
            log_warning "Cleaning up and retrying in 10s..."
            # 清理旧的配置，避免状态不一致导致下一次重试失败
            acme.sh --remove -d "$DOMAIN" >/dev/null 2>&1 || true
            rm -rf "/acme.sh/${DOMAIN}_ecc" || true
            
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
