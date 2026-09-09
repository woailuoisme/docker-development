#!/usr/bin/env bash
set -euo pipefail

# 终端色彩输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}==> 启动 mkcert 本地证书自动化生成器...${NC}"

# 1. 处理 Root CA 持久化
export CAROOT="/root/.local/share/mkcert"
mkdir -p "${CAROOT}"

if [ -f "${CAROOT}/rootCA.pem" ] && [ -f "${CAROOT}/rootCA-key.pem" ]; then
	echo -e "${YELLOW}[CA] 检测到持久化 Root CA 证书已存在于 ${CAROOT}${NC}"
else
	echo -e "${YELLOW}[CA] 未找到现有 Root CA，正在初始化生成新本地根证书...${NC}"
	mkcert -install
fi

# 2. 将 Root CA 复制到统一输出目录供宿主机导入与服务挂载
TARGET_CA_DIR="/ssl/ca"
mkdir -p "${TARGET_CA_DIR}"
cp "${CAROOT}/rootCA.pem" "${TARGET_CA_DIR}/rootCA.pem"

echo -e "${GREEN}[CA] Root CA 已成功分发至: ${TARGET_CA_DIR}/rootCA.pem${NC}"
echo -e "${BLUE}[CA] 宿主机信任提示:${NC}"
echo -e "  - macOS: just trust-mkcert (或: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${TARGET_CA_DIR}/rootCA.pem)"
echo -e "  - Linux: sudo cp ${TARGET_CA_DIR}/rootCA.pem /usr/local/share/ca-certificates/mkcert-rootCA.crt && sudo update-ca-certificates"

# 3. 组装域名列表（含顶级通配符与本地回环）
SITE_ADDRESS="${SITE_ADDRESS:-test.local}"
EXTRA_DOMAINS="${DOMAINS:-}"

# 基础 SAN 列表：基础域名、泛域名、localhost、回环 IP 以及 *.local 泛域名
BASE_DOMAINS="${SITE_ADDRESS} *.${SITE_ADDRESS} localhost 127.0.0.1 ::1 *.local"
ALL_DOMAINS="${BASE_DOMAINS} ${EXTRA_DOMAINS}"

# 解析为 Bash 数组避免展开注水与解析异常
read -ra DOMAIN_LIST <<< "${ALL_DOMAINS}"

echo -e "${GREEN}[CERT] 正在为以下域名签发全量 SAN 证书:${NC}"
for domain in "${DOMAIN_LIST[@]}"; do
	echo -e "  - ${domain}"
done

# 4. 生成统一标准的证书文件（对齐 Traefik 与 Nginx 挂载路径）
TARGET_CERT_DIR="/ssl/live/${SITE_ADDRESS}"
mkdir -p "${TARGET_CERT_DIR}"

mkcert \
	-cert-file "${TARGET_CERT_DIR}/fullchain.pem" \
	-key-file "${TARGET_CERT_DIR}/privkey.pem" \
	"${DOMAIN_LIST[@]}"

# 同时同步至 /ssl/live/local 兼容旧路径与默认回退
LOCAL_CERT_DIR="/ssl/live/local"
mkdir -p "${LOCAL_CERT_DIR}"
cp "${TARGET_CERT_DIR}/fullchain.pem" "${LOCAL_CERT_DIR}/fullchain.pem"
cp "${TARGET_CERT_DIR}/privkey.pem" "${LOCAL_CERT_DIR}/privkey.pem"

echo -e "${GREEN}✔ 证书签发与分发完成:${NC}"
echo -e "  - 站点主证书: ${TARGET_CERT_DIR}/fullchain.pem"
echo -e "  - 站点私钥:   ${TARGET_CERT_DIR}/privkey.pem"
echo -e "  - 本地镜像:   ${LOCAL_CERT_DIR}/fullchain.pem"
echo -e "${GREEN}==> 所有证书任务已成功执行完成。${NC}"
