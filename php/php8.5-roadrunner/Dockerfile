# PHP 8.5 Base RoadRunner Alpine Image
# ============================================================================
FROM jiaoio/php8.5:cli
LABEL maintainer="seaside <531773730@qq.com>"

# Alpine 基础镜像需要安装 libc6-compat 或 gcompat 以运行 glibc 编译的 RoadRunner
RUN set -eux; \
    apk add --no-cache gcompat

# 必须声明此 ARG，Docker BuildKit 会自动填充它
ARG TARGETARCH
ARG ROADRUNNER_VERSION=2025.1.15

COPY download-roadrunner.sh /tmp/download-roadrunner.sh
RUN export TARGETARCH=${TARGETARCH} && \
    chmod +x /tmp/download-roadrunner.sh && \
    ROADRUNNER_VERSION=${ROADRUNNER_VERSION} /tmp/download-roadrunner.sh && \
    rm /tmp/download-roadrunner.sh