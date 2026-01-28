#!/bin/sh
# Certbot 健康检查：检查证书是否存在
set -e

DOMAIN=${DOMAIN:-haoxiaoguai.xyz}
CERT_FILE="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

if [ -f "$CERT_FILE" ]; then
    echo "[$(date '+%H:%M:%S')] 证书已就绪: $DOMAIN"
    exit 0
else
    echo "[$(date '+%H:%M:%S')] 证书未找到: $DOMAIN"
    exit 1
fi
