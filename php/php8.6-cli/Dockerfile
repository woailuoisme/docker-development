# ============================================================================
# PHP 8.6 Base CLI Alpine Image (via pkg.henderkes.com apk)
# ============================================================================
FROM alpine:3.24
LABEL maintainer="seaside <531773730@qq.com>"

# ============================================================================
# 构建参数配置
# ============================================================================

ARG TIMEZONE=Asia/Shanghai
ARG PHP_ZTS_VERSION=86

ENV TZ=${TIMEZONE}

# 可选功能开关 (对应 php-zts-* apk 包与系统工具)
ARG WITH_PG=true
ARG WITH_VIPS=true
ARG WITH_OPEN_TELEMETRY=false
ARG WITH_IMAGICK=false
ARG WITH_UV=false
ARG WITH_MYSQL=false
ARG WITH_MONGODB=false
ARG WITH_AMQP=false
ARG WITH_RDKAFKA=false
ARG WITH_CLICKHOUSE=false
ARG WITH_XLSWRITER=false
ARG WITH_FFMPEG=false
ARG WITH_LDAP=false
ARG WITH_PIE=false

# ============================================================================
# 系统依赖与环境配置
# ============================================================================

RUN set -eux; \
    apk add --no-cache \
    ca-certificates curl tzdata gettext-envsubst gosu tini postgresql18-client procps iproute2 iputils \
    jpegoptim \
    pngquant \
    optipng \
    gifsicle \
    libwebp-tools \
    libavif-apps; \
    if [ "$WITH_FFMPEG" = "true" ]; then \
    apk add --no-cache ffmpeg; \
    fi; \
    if [ "$WITH_VIPS" = "true" ]; then \
    apk add --no-cache vips vips-tools vips-heif; \
    fi; \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime; \
    echo "${TIMEZONE}" > /etc/timezone

# ============================================================================
# 安装 PHP ZTS CLI 与扩展 (pkg.henderkes.com)
# ============================================================================

WORKDIR /tmp

RUN set -eux; \
    echo "https://pkg.henderkes.com/api/packages/${PHP_ZTS_VERSION}/alpine/main/php-zts" >> /etc/apk/repositories; \
    KEYFILE=$(curl -fsSJOw '%{filename_effective}' "https://pkg.henderkes.com/api/packages/${PHP_ZTS_VERSION}/alpine/key"); \
    mv "${KEYFILE}" /etc/apk/keys/; \
    apk add --no-cache \
    php-zts-cli \
    php-zts-curl \
    php-zts-fileinfo \
    php-zts-pdo_sqlite \
    php-zts-redis \
    php-zts-bcmath \
    php-zts-gmp \
    php-zts-protobuf \
    php-zts-intl \
    php-zts-zip \
    php-zts-ffi \
    php-zts-gd; \
    if [ "${WITH_MYSQL}" = "true" ]; then apk add --no-cache php-zts-mysqli php-zts-pdo_mysql; fi; \
    if [ "${WITH_PG}" = "true" ]; then apk add --no-cache php-zts-pgsql php-zts-pdo_pgsql; fi; \
    if [ "${WITH_MONGODB}" = "true" ]; then apk add --no-cache php-zts-mongodb; fi; \
    if [ "${WITH_LDAP}" = "true" ]; then apk add --no-cache php-zts-ldap; fi; \
    if [ "${WITH_AMQP}" = "true" ]; then apk add --no-cache php-zts-amqp; fi; \
    if [ "${WITH_UV}" = "true" ]; then apk add --no-cache php-zts-uv; fi; \
    if [ "${WITH_IMAGICK}" = "true" ]; then apk add --no-cache php-zts-imagick; fi; \
    if [ "${WITH_OPEN_TELEMETRY}" = "true" ]; then apk add --no-cache php-zts-opentelemetry; fi; \
    if [ "${WITH_XLSWRITER}" = "true" ]; then apk add --no-cache php-zts-xlswriter; fi; \
    if [ "${WITH_RDKAFKA}" = "true" ]; then apk add --no-cache php-zts-rdkafka; fi; \
    if [ "${WITH_CLICKHOUSE}" = "true" ]; then apk add --no-cache php-zts-clickhouse; fi; \
    if [ "${WITH_PIE}" = "true" ]; then apk add --no-cache pie-zts; fi; \
    if [ "${WITH_VIPS}" = "true" ]; then \
    mkdir -p /etc/php-zts/conf.d; \
    { \
    echo "ffi.enable=true"; \
    echo "zend.max_allowed_stack_size=-1"; \
    } > /etc/php-zts/conf.d/99-vips.ini; \
    fi; \
    rm -rf /var/cache/apk/*

WORKDIR /

# 生产环境 PHP / Laravel CLI 配置
COPY laravel.ini /etc/php-zts/conf.d/

CMD ["php", "-a"]
