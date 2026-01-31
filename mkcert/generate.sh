#!/bin/sh
set -e

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting mkcert generator...${NC}"

# 1. 处理 Root CA
# mkcert 默认将 CA 存储在 CAROOT 环境变量指定的位置，或者 ~/.local/share/mkcert
export CAROOT=/root/.local/share/mkcert

# 确保存储目录存在
mkdir -p "$CAROOT"

if [ -f "$CAROOT/rootCA.pem" ]; then
    echo -e "${YELLOW}Existing Root CA found at $CAROOT${NC}"
else
    echo -e "${YELLOW}No Root CA found. Generating new Root CA...${NC}"
    mkcert -install
fi

# 2. 将 Root CA 复制到输出目录，供用户安装到宿主机
# 假设 /ssl 挂载到了 ../nginx-simple/ssl
TARGET_CA_DIR="/ssl/ca"
mkdir -p "$TARGET_CA_DIR"

cp "$CAROOT/rootCA.pem" "$TARGET_CA_DIR/rootCA.pem"
echo -e "${GREEN}Root CA copied to $TARGET_CA_DIR/rootCA.pem${NC}"
echo -e "${YELLOW}IMPORTANT: Please install this Root CA on your host machine to trust these certificates.${NC}"
echo -e "  Mac: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $TARGET_CA_DIR/rootCA.pem"
echo -e "  Linux: sudo cp $TARGET_CA_DIR/rootCA.pem /usr/local/share/ca-certificates/rootCA.crt && sudo update-ca-certificates"

# 3. 生成域名证书
DOMAINS=${DOMAINS:-"localhost 127.0.0.1 ::1"}
CERT_NAME="local"
TARGET_CERT_DIR="/ssl/live/$CERT_NAME"

echo -e "${GREEN}Generating certificates for domains: $DOMAINS${NC}"
mkdir -p "$TARGET_CERT_DIR"

# 生成证书
# 直接输出到目标目录
mkcert -cert-file "$TARGET_CERT_DIR/fullchain.pem" \
       -key-file "$TARGET_CERT_DIR/privkey.pem" \
       $DOMAINS

echo -e "${GREEN}Certificates generated at:${NC}"
echo -e "  Cert: $TARGET_CERT_DIR/fullchain.pem"
echo -e "  Key:  $TARGET_CERT_DIR/privkey.pem"

# 保持容器运行一段时间以便查看日志，或者直接退出
# 如果作为一次性任务运行，直接退出即可
echo -e "${GREEN}Task completed successfully.${NC}"
