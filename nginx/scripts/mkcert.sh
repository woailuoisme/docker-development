#!/bin/bash

# ==============================================================================
# 本地开发证书生成脚本 (使用 mkcert)
# ==============================================================================
# 作用：生成受本地信任的通配符证书，用于 HTTPS 开发测试。
# 依赖：需在宿主机安装 mkcert (brew install mkcert)
# ==============================================================================

# 设置基础变量
DOMAIN="test.xyz"
SSL_DIR="$(cd "$(dirname "$0")/../ssl" && pwd)"
TARGET_DIR="${SSL_DIR}/live/${DOMAIN}"

# 确保目标目录存在
mkdir -p "${TARGET_DIR}"

echo "Checking mkcert installation..."
if ! command -v mkcert &> /dev/null; then
    echo "Error: mkcert is not installed. Please run 'brew install mkcert' first."
    exit 1
fi

# 初始化 mkcert (安装根证书到本地信任库，仅需运行一次)
mkcert -install

echo "Generating local certificates for ${DOMAIN} and its subdomains..."

# 生成证书
# $TARGET_DIR/fullchain.pem (证书)
# $TARGET_DIR/privkey.pem (私钥)
mkcert -cert-file "${TARGET_DIR}/fullchain.pem" \
       -key-file "${TARGET_DIR}/privkey.pem" \
       "${DOMAIN}" "*.${DOMAIN}" "localhost" "127.0.0.1" "::1"

echo "=============================================================================="
echo "Certificates generated successfully!"
echo "Location: ${TARGET_DIR}"
echo "Files:"
echo "  - fullchain.pem (Certificate)"
echo "  - privkey.pem   (Private Key)"
echo "=============================================================================="
echo "Note: Ensure Nginx is configured to use these paths."
