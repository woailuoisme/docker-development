ARG CHANGE_SOURCE=true
# PHP-FPM 服务镜像 - 基于 php-base 镜像构建
#FROM jiaoio/php-base-fpm
FROM jiaoio/php-base-fpm:8.5-fpm-latest
#FROM quay.io/jiaoio/php-base-fpm
#FROM ccr.ccs.tencentyun.com/jiaoio/php-base-fpm
LABEL maintainer="seaside <531773730@qq.com>"

# 动态用户ID支持
ARG WWWUSER=33
ARG WWWGROUP=33

LABEL service="php-fpm"

ENV APP_ENABLE=true \
    APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    APP_DEBUG=false \
    WORKER_QUEUE=default,broadcasting,order,mail,sms \
    ENABLE_SUPERVISOR=false \
    ENABLE_SCHEDULE=false \
    ENABLE_HORIZON=false \
    ENABLE_WORKER=false \
    ENABLE_REVERB=false \
    ENABLE_PULSE=false \
    COMPOSER_ALLOW_SUPERUSER=1 \
    MAGICK_THREAD_LIMIT=2 \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

#RUN pecl install xdebug-3.2.1 \
#    && docker-php-ext-enable xdebug
## 配置 Xdebug
#COPY config/xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# 创建 Supervisor 配置目录（php-base 已创建基础目录）
RUN mkdir -p /usr/local/etc/supervisord.d \
    && chown -R www-data:www-data /usr/local/etc/supervisord.d \
    && chmod 755 /usr/local/etc/supervisord.d

# 创建 cron 配置目录
RUN mkdir -p /usr/local/etc \
    && chown -R www-data:www-data /usr/local/etc \
    && chmod 755 /usr/local/etc

# 复制 PHP 配置（php-base 已创建 /usr/local/etc/php/conf.d 目录）
COPY config/*.ini /usr/local/etc/php/conf.d/
COPY config/www.conf /usr/local/etc/php-fpm.d/www.conf

# 复制 Supervisor 主配置文件
COPY supervisord.conf /usr/local/etc/supervisord.conf
COPY startup.sh /usr/local/bin/startup.sh

# 设置启动脚本执行权限（php-base 已设置用户和目录权限）
RUN chmod +x /usr/local/bin/startup.sh

# 创建 PHP-FPM 日志目录
RUN mkdir -p /var/log/php-fpm \
    && chown -R www-data:www-data /var/log/php-fpm \
    && chmod 755 /var/log/php-fpm

# 创建 .ssh 目录并添加 GitHub、Gitee 主机指纹（用于挂载SSH密钥）
RUN mkdir -p /home/www-data/.ssh \
    && chown -R www-data:www-data /home/www-data/.ssh \
    && chmod 700 /home/www-data/.ssh
#    && ssh-keyscan github.com >> /home/www-data/.ssh/known_hosts \
#    && ssh-keyscan gitee.com >> /home/www-data/.ssh/known_hosts \
#    && chown www-data:www-data /home/www-data/.ssh/known_hosts \
#    && chmod 644 /home/www-data/.ssh/known_hosts

HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD sh -c 'SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 | grep -q pong'

#WORKDIR /var/www
WORKDIR $APP_PATH
EXPOSE 9000 8080 8001
USER www-data
ENTRYPOINT ["/usr/local/bin/startup.sh"]
