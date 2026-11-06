# ============================================================================
# PHP 8.5 Base FrankenPHP Alpine Image
# ============================================================================
FROM dunglas/frankenphp:1.13-php8.5-alpine
LABEL maintainer="seaside <531773730@qq.com>"

# ============================================================================
# 构建参数配置
# ============================================================================

ARG CHINA=false
ARG TZ=Asia/Shanghai

# 可选功能开关
ARG WITH_PG=true
ARG WITH_VIPS=true
ARG WITH_OPEN_TELEMETRY=true
ARG WITH_IMAGICK=true
ARG WITH_UV=false
ARG WITH_MYSQL=false
ARG WITH_MONGODB=false
ARG WITH_AMQP=false
ARG WITH_RDKAFKA=false
ARG WITH_SEASCLICK=false
ARG WITH_MD4C=false
ARG WITH_XLSWRITER=false

ARG WITH_FFMPEG=false
ARG WITH_LDAP=false
ARG WITH_SWOOLE=false

# ============================================================================
# 系统依赖与环境配置
# ============================================================================

# 1. 系统依赖、运行时库与环境配置 (合并层以减小体积)
RUN set -eux; \
    if [ "$CHINA" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi; \
    apk add --no-cache \
    tzdata gettext gosu tini postgresql18-client procps iproute2 iputils \
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
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime; \
    echo "${TZ}" > /etc/timezone

# ============================================================================
# PHP 扩展编译与安装 (合并层以减小体积)
# ============================================================================

# 4. 配置 & 安装核心扩展
# 基础镜像已预置: Core, ctype, curl, date, dom, fileinfo, filter, hash, iconv, json,
# lexbor, libxml, mbstring, mysqlnd, openssl, pcre, PDO, pdo_sqlite, Phar, posix,
# random, readline, Reflection, session, SimpleXML, sodium, SPL, sqlite3, standard,
# tokenizer, uri, xml, xmlreader, xmlwriter, Zend OPcache, zlib
RUN set -eux; \
    install-php-extensions igbinary simdjson redis; \
    install-php-extensions bcmath gmp exif pcntl sockets protobuf intl zip ffi gd; \
    if [ "${WITH_MYSQL:-false}" = "true" ]; then install-php-extensions mysqli pdo_mysql; fi; \
    if [ "${WITH_PG:-false}" = "true" ]; then install-php-extensions pgsql pdo_pgsql; fi; \
    if [ "${WITH_MONGODB:-false}" = "true" ]; then install-php-extensions mongodb; fi; \
    if [ "${WITH_LDAP:-false}" = "true" ]; then install-php-extensions ldap; fi; \
    if [ "${WITH_AMQP:-false}" = "true" ]; then install-php-extensions amqp; fi; \
    if [ "${WITH_SWOOLE:-false}" = "true" ]; then install-php-extensions swoole; fi; \
    if [ "${WITH_UV:-false}" = "true" ]; then install-php-extensions uv; fi; \
    if [ "${WITH_IMAGICK:-false}" = "true" ]; then install-php-extensions imagick; fi; \
    if [ "${WITH_OPEN_TELEMETRY:-false}" = "true" ]; then install-php-extensions opentelemetry; fi; \
    if [ "${WITH_XLSWRITER:-false}" = "true" ]; then install-php-extensions xlswriter; fi; \
    if [ "${WITH_RDKAFKA:-false}" = "true" ]; then install-php-extensions rdkafka; fi; \
    if [ "${WITH_SEASCLICK:-false}" = "true" ]; then install-php-extensions seasclick; fi; \
    if [ "${WITH_MD4C:-false}" = "true" ]; then install-php-extensions md4c; fi; \
    if [ "${WITH_VIPS:-false}" = "true" ]; then \
    echo "ffi.enable=true" > /usr/local/etc/php/conf.d/docker-php-ext-vips.ini; \
    echo "zend.max_allowed_stack_size=-1" >> /usr/local/etc/php/conf.d/docker-php-ext-vips.ini; \
    fi; \
    rm -rf /tmp/pear /var/cache/apk/*; \
    find /usr/local/lib/php -name "*.a" -delete; \
    find /usr/local/lib/php -name "*.la" -delete

# ============================================================================
# 用户、目录与权限配置
# ============================================================================

# 6. 运行目录与权限配置（直接沿用 Alpine 原生 www-data: 82:82）
RUN set -eux; \
    mkdir -p /var/www /var/log/php; \
    chown -R www-data:www-data /var/www /var/log/php

# 7. 生产环境 PHP / Laravel 配置
COPY laravel.ini /usr/local/etc/php/conf.d/

WORKDIR /var/www
