#!/bin/bash

# ================= 配置区域 =================
# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 证书存放路径（相对于项目根目录）
TARGET_DIR="${SCRIPT_DIR}/../certs"
# 域名和 IP 配置
DOMAINS=(
    "localhost"
    "127.0.0.1"
    "*.local"
    "*.test"
    "*.test.local"
)
# ===========================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 确保目标目录存在
mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

log_info "1. 检查 mkcert 环境..."
if ! command -v mkcert &> /dev/null; then
    log_warn "未检测到 mkcert，正在尝试安装..."
    if command -v brew &> /dev/null; then
        brew install mkcert nss
    else
        log_error "请先安装 Homebrew: https://brew.sh"
        log_error "或手动安装 mkcert: brew install mkcert nss"
        exit 1
    fi
fi

log_info "2. 安装并信任本地 CA..."
mkcert -install

log_info "3. 生成域名证书和私钥..."
log_info "   域名列表: ${DOMAINS[*]}"

cd "$TARGET_DIR"
mkcert -cert-file server.crt -key-file server.key "${DOMAINS[@]}"

log_info "4. 导出根证书 (rootCA.pem)..."
cp "$(mkcert -CAROOT)/rootCA.pem" "$TARGET_DIR/rootCA.pem"

# 设置适当的权限
chmod 644 "$TARGET_DIR/server.crt" "$TARGET_DIR/rootCA.pem"
chmod 600 "$TARGET_DIR/server.key"

echo ""
echo "-------------------------------------------"
log_info "✅ 证书生成完成！"
echo ""
echo "  证书位置: $TARGET_DIR/server.crt"
echo "  私钥位置: $TARGET_DIR/server.key"
echo "  根证书:   $TARGET_DIR/rootCA.pem"
echo ""
echo "  根证书可用于导入到其他设备（手机/其他电脑）"
echo "-------------------------------------------"
echo ""
ls -lh "$TARGET_DIR"