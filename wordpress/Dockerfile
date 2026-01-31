FROM wordpress:6.9-php8.4-fpm-alpine

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

ARG CHANGE_SOURCE=true
ARG TIMEZONE=Asia/Shanghai

RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi && \
    apk add --no-cache tzdata fcgi mysql-client && \
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone

RUN install-php-extensions redis

RUN mkdir -p /var/log/php-fpm && \
    chown -R www-data:www-data /var/log/php-fpm && \
    touch /var/www/ping.php

# 复制配置文件
COPY config/wp.ini /usr/local/etc/php/conf.d/wp.ini
COPY config/www.conf /usr/local/etc/php-fpm.d/zz-www.conf

# 安装 wp-cli 并设置初始化脚本
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

COPY scripts/init-wp.sh /usr/local/bin/init-wp.sh
RUN chmod +x /usr/local/bin/init-wp.sh && \
    sed -i '/exec "$@"/i /usr/local/bin/init-wp.sh' /usr/local/bin/docker-entrypoint.sh

# 健康检测
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD SCRIPT_NAME=/ping.php SCRIPT_FILENAME=/var/www/ping.php REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1
