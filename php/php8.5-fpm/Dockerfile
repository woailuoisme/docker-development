# ============================================================================
# PHP 8.5 Alpine Base FPM Image
# ============================================================================
ARG PHP_VERSION=8.5-fpm-alpine3.24
FROM php:${PHP_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

# ============================================================================
# 构建参数配置
# ============================================================================

ARG CHINA=false
ARG TIMEZONE=Asia/Shanghai

# 可选功能开关
ARG WITH_PG=true
ARG WITH_VIPS=true
ARG WITH_OPEN_TELEMETRY=true
ARG WITH_IMAGICK=false
ARG WITH_MYSQL=false
ARG WITH_UV=false
ARG WITH_XDEBUG=false
ARG WITH_AMQP=false
ARG WITH_MONGODB=false
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
    apk update; \
    apk add --no-cache \
    curl tzdata gettext gosu postgresql18-client procps iproute2 iputils fcgi \
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
# PHP 扩展安装 (使用 install-php-extensions 简化构建)
# ============================================================================

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# 4. 安装扩展
# 默认已安装扩展: Core, ctype, curl, date, dom, fileinfo, filter, hash, iconv, json
# lexbor, libxml, mbstring, mysqlnd, openssl, pcre, PDO, pdo_sqlite, Phar, posix
# random, readline, Reflection, session, SimpleXML, sodium, SPL, sqlite3, standard
# tokenizer, uri, xml, xmlreader, xmlwriter, Zend OPcache, zlib
RUN set -eux; \
    install-php-extensions igbinary simdjson redis; \
    install-php-extensions \
    bcmath gmp exif pcntl sockets protobuf intl zip ffi  \
    gd; \
    if [ "${WITH_MYSQL:-false}" = "true" ]; then install-php-extensions mysqli pdo_mysql; fi; \
    if [ "${WITH_PG:-false}" = "true" ]; then install-php-extensions pgsql pdo_pgsql; fi; \
    if [ "${WITH_MONGODB:-false}" = "true" ]; then install-php-extensions mongodb; fi; \
    if [ "${WITH_LDAP:-false}" = "true" ]; then install-php-extensions ldap; fi; \
    if [ "${WITH_AMQP:-false}" = "true" ]; then install-php-extensions amqp; fi; \
    if [ "${WITH_SWOOLE:-false}" = "true" ]; then install-php-extensions swoole; fi; \
    if [ "${WITH_UV:-false}" = "true" ]; then install-php-extensions uv; fi; \
    if [ "${WITH_IMAGICK:-false}" = "true" ]; then install-php-extensions imagick; fi; \
    if [ "${WITH_OPEN_TELEMETRY:-false}" = "true" ]; then install-php-extensions opentelemetry; fi; \
    if [ "${WITH_XDEBUG:-false}" = "true" ]; then install-php-extensions xdebug-^3@stable spx; fi; \
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
    touch /var/log/php/fpm.slow.log; \
    chown -R www-data:www-data /var/www /var/log/php; \
    chmod 644 /var/log/php/fpm.slow.log

# 7. 生产环境 PHP / Laravel FPM 配置
COPY laravel.ini /usr/local/etc/php/conf.d/
COPY www.conf /usr/local/etc/php-fpm.d/

WORKDIR /var/www

EXPOSE 9000 9001 9003

# 8. 生产环境 FPM 健康检查（利用 cgi-fcgi 向 9000 端口请求 /ping 探针）
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD ["sh", "-c", "SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1"]
