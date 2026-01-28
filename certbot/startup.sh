#!/bin/sh
set -e

# 基础配置
DNS_PROVIDER=${DNS_PROVIDER:-cloudflare}
DOMAIN=${DOMAIN:-example.com}
EMAIL=${EMAIL:-admin@gmail.com}
RENEW_INTERVAL=${RENEW_INTERVAL:-43200}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# 生成凭据文件
gen_creds() {
    local file="/tmp/creds.ini"
    case "$DNS_PROVIDER" in
        "cloudflare")
            [ -n "$CLOUDFLARE_API_TOKEN" ] && echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" > $file || \
            { echo "dns_cloudflare_email = $CLOUDFLARE_EMAIL" > $file; echo "dns_cloudflare_api_key = $CLOUDFLARE_API_KEY" >> $file; }
            ;;
        "aliyun")
            echo "dns_aliyun_access_key = $ALIYUN_ACCESS_KEY_ID" > $file
            echo "dns_aliyun_access_key_secret = $ALIYUN_ACCESS_KEY_SECRET" >> $file
            ;;
    esac
    chmod 600 $file
    echo "$file"
}

# 证书操作 (申请或续签)
cert_action() {
    local creds=$(gen_creds)
    if [ "$1" = "run" ]; then
        log "正在为 $DOMAIN 申请证书 ($DNS_PROVIDER)..."
        certbot certonly --non-interactive --authenticator dns-$DNS_PROVIDER --dns-$DNS_PROVIDER-credentials $creds \
            --dns-$DNS_PROVIDER-propagation-seconds 60 --email "$EMAIL" --agree-tos --no-eff-email \
            --expand --domains "$DOMAIN,*.$DOMAIN"
    else
        log "执行证书续签检查..."
        certbot renew --quiet
    fi
    rm -f $creds
}

# 主流程
log "Certbot 启动: $DOMAIN via $DNS_PROVIDER"

# 首次启动检查
[ -d "/etc/letsencrypt/live/$DOMAIN" ] || cert_action "run"

# 自动续签循环
trap 'exit 0' TERM INT
while true; do
    sleep "$RENEW_INTERVAL" & wait $!
    cert_action "renew"
done
