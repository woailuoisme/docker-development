ARG CHANGE_SOURCE=true
# PHP-FPM 服务镜像 - 基于 php-base 镜像构建
#FROM jiaoio/php-base-fpm
#FROM jiaoio/php-base-fpm:8.5-fpm-latest
#FROM quay.io/jiaoio/php-base-fpm
#FROM ccr.ccs.tencentyun.com/jiaoio/php-base-fpm
ARG PHP_VERSION=8.5
FROM jiaoio/php-base-fpm-trixie:${PHP_VERSION}-fpm-latest
LABEL maintainer="seaside <531773730@qq.com>"

# 动态用户ID支持
ARG WWWUSER=33
ARG WWWGROUP=33

LABEL service="php-fpm"

ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    APP_DEBUG=false \
    TZ=Asia/Shanghai \
    CHANGE_SOURCE=${CHANGE_SOURCE} \
    COMPOSER_ALLOW_SUPERUSER=1 \
    MAGICK_THREAD_LIMIT=2 \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

# 切换镜像源 (Debian Trixie)
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 设置系统时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# 创建 cron 配置目录
RUN mkdir -p /usr/local/etc \
    && chown -R www-data:www-data /usr/local/etc \
    && chmod 755 /usr/local/etc

# 复制 PHP 配置
COPY config/*.ini /usr/local/etc/php/conf.d/
COPY config/www.conf /usr/local/etc/php-fpm.d/www.conf

# 复制启动脚本和健康检查脚本
COPY startup.sh /usr/local/bin/startup.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/startup.sh \
    && chmod +x /usr/local/bin/healthcheck.sh

# 创建 PHP-FPM 日志目录
RUN mkdir -p /var/log/php-fpm \
    && chown -R www-data:www-data /var/log/php-fpm \
    && chmod 755 /var/log/php-fpm

# 创建 .ssh 目录并添加 GitHub、Gitee 主机指纹（用于挂载SSH密钥）
RUN mkdir -p /home/www-data/.ssh \
    && chown -R www-data:www-data /home/www-data/.ssh \
    && chmod 700 /home/www-data/.ssh

HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

#WORKDIR /var/www
WORKDIR $APP_PATH
EXPOSE 9000 8080 8001
USER www-data
ENTRYPOINT ["/usr/local/bin/startup.sh"]
