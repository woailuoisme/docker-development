#!/bin/sh
set -e

# FrankenPHP Binary Download Script

VERSION="${FRANKENPHP_VERSION:-1.13.1}"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="frankenphp"

info() { echo "[INFO] $1"; }
success() { echo "[SUCCESS] $1"; }
error() { echo "[ERROR] $1" >&2; }

# 检测架构（优先使用 Docker BuildKit TARGETARCH）
if [ -n "$TARGETARCH" ]; then
	case "$TARGETARCH" in
	amd64) ARCH="x86_64" ;;
	arm64) ARCH="aarch64" ;;
	*)
		error "Unsupported TARGETARCH: $TARGETARCH"
		exit 1
		;;
	esac
else
	case "$(uname -m)" in
	x86_64 | amd64) ARCH="x86_64" ;;
	aarch64 | arm64) ARCH="aarch64" ;;
	*)
		error "Unsupported architecture: $(uname -m)"
		exit 1
		;;
	esac
fi

OS="linux"
PLATFORM="${OS}-${ARCH}"
TARGET="${INSTALL_DIR}/${BINARY_NAME}"

info "Installing FrankenPHP v${VERSION} for ${PLATFORM}..."

# 多镜像源顺序尝试
DOWNLOAD_SOURCES="
https://github.com/php/frankenphp/releases/download/v${VERSION}/frankenphp-${PLATFORM}
https://github.com/dunglas/frankenphp/releases/download/v${VERSION}/frankenphp-${PLATFORM}
"

DOWNLOADED=false
for URL in $DOWNLOAD_SOURCES; do
	info "Trying: $URL"
	if curl -fSL --progress-bar "$URL" -o "$TARGET" 2>/dev/null; then
		DOWNLOADED=true
		break
	else
		echo "  -> failed, trying next..."
		rm -f "$TARGET"
	fi
done

if [ "$DOWNLOADED" = "false" ]; then
	error "All download sources failed for FrankenPHP v${VERSION}"
	exit 1
fi

chmod +x "$TARGET"

# 验证安装
if "$TARGET" --version; then
	success "FrankenPHP v${VERSION} installed successfully!"
else
	error "Installation verification failed"
	exit 1
fi
