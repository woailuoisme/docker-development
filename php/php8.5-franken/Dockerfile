# PHP 8.5 Base FrankenPHP Alpine Image
# ============================================================================
FROM jiaoio/php8.5:cli
LABEL maintainer="seaside <531773730@qq.com>"

# 必须声明此 ARG，Docker BuildKit 会自动填充它
ARG TARGETARCH
ARG FRANKENPHP_VERSION=1.13.1

ENV VERSION=${FRANKENPHP_VERSION} \
    FRANKENPHP_VERSION=${FRANKENPHP_VERSION}

# 根据架构下载对应的 FrankenPHP 静态二进制文件并验证（支持多个镜像源）
# Alpine 基础镜像需要安装 libc6-compat 才能运行某些静态库或特定的二进制环境
RUN set -eux; \
    apk add --no-cache libc6-compat

COPY download-frankenphp.sh /usr/local/bin/download-frankenphp.sh
RUN export TARGETARCH=${TARGETARCH} && \
    chmod +x /usr/local/bin/download-frankenphp.sh && \
    /usr/local/bin/download-frankenphp.sh && \
    rm -f /usr/local/bin/download-frankenphp.sh && \
    frankenphp --version
