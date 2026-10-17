#!/bin/sh
set -e

# RoadRunner Binary Download Script

VERSION="${ROADRUNNER_VERSION:-2025.1.15}"
OS="linux"

info()    { echo "[INFO] $1"; }
success() { echo "[SUCCESS] $1"; }
error()   { echo "[ERROR] $1" >&2; }

# 检测架构（优先使用 Docker BuildKit TARGETARCH）
if [ -n "$TARGETARCH" ]; then
    case "$TARGETARCH" in
        amd64) ARCH="amd64" ;;
        arm64) ARCH="arm64" ;;
        *) error "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;;
    esac
else
    case "$(uname -m)" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
fi

info "Installing RoadRunner v${VERSION} for ${OS}/${ARCH}..."

# 多镜像源顺序尝试
ARCHIVE="roadrunner-${VERSION}-${OS}-${ARCH}.tar.gz"
DOWNLOAD_SOURCES="
https://github.com/roadrunner-server/roadrunner/releases/download/v${VERSION}/${ARCHIVE}
https://github.com/spiral/roadrunner/releases/download/v${VERSION}/${ARCHIVE}
"

TMP_DIR=$(mktemp -d)
DOWNLOADED=false

for URL in $DOWNLOAD_SOURCES; do
    info "Trying: $URL"
    if curl -fSL --progress-bar "$URL" -o "${TMP_DIR}/${ARCHIVE}" 2>/dev/null; then
        DOWNLOADED=true
        break
    else
        echo "  -> failed, trying next..."
    fi
done

if [ "$DOWNLOADED" = "false" ]; then
    error "All download sources failed for RoadRunner v${VERSION}"
    rm -rf "$TMP_DIR"
    exit 1
fi

info "Extracting..."
tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "$TMP_DIR"

RR_BINARY=$(find "$TMP_DIR" -type f \( -name "rr" -o -name "roadrunner" \) | head -n 1)
if [ -z "$RR_BINARY" ]; then
    error "RoadRunner binary not found after extraction"
    rm -rf "$TMP_DIR"
    exit 1
fi

mv "$RR_BINARY" /usr/local/bin/rr
chmod +x /usr/local/bin/rr
rm -rf "$TMP_DIR"

# 验证安装
if /usr/local/bin/rr --version; then
    success "RoadRunner v${VERSION} installed successfully!"
else
    error "Installation verification failed"
    exit 1
fi
