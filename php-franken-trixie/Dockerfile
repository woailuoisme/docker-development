ARG PHP_VERSION=8.5
FROM jiaoio/php-base-franken-trixie:${PHP_VERSION}-latest

ARG CHANGE_SOURCE=true

ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    APP_DEBUG=false \
    TZ=Asia/Shanghai \
    CHANGE_SOURCE=${CHANGE_SOURCE} \
    OCTANE_SERVER=frankenphp \
    OCTANE_HOST=0.0.0.0 \
    OCTANE_WORKERS=4 \
    OCTANE_MAX_REQUESTS=300 \
    OCTANE_ADMIN_PORT=2019 \
    WATCH=false \
    OCTANE_POLL=false \
    OCTANE_HTTPS=false \
    OCTANE_HTTP_REDIRECT=false \
    OCTANE_LOG_LEVEL=info \
    ENABLE_OCTANE_LOG_LEVEL=true \
    COMPOSER_ALLOW_SUPERUSER=1 \
    MAGICK_THREAD_LIMIT=2 \
    CADDY_GLOBAL_OPTIONS={"log":{"format":"console"}} \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

# 切换镜像源 (Debian Trixie)
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 设置系统时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# 复制PHP配置
COPY config/*.ini /usr/local/etc/php/conf.d/

# 复制启动脚本
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# 复制健康检查脚本
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# 创建 Caddy/FrankenPHP 所需的目录并设置权限
RUN mkdir -p /data/caddy \
    && mkdir -p /config/caddy \
    && mkdir -p /home/www-data/.local/share/caddy \
    && mkdir -p /home/www-data/.config/caddy \
    && chown -R www-data:www-data /data/caddy \
    && chown -R www-data:www-data /config/caddy \
    && chown -R www-data:www-data /home/www-data/.local \
    && chown -R www-data:www-data /home/www-data/.config

# 创建 .ssh 目录并添加 GitHub、Gitee 主机指纹（用于挂载SSH密钥）
RUN mkdir -p /home/www-data/.ssh \
    && chown -R www-data:www-data /home/www-data/.ssh \
    && chmod 700 /home/www-data/.ssh \
    && ssh-keyscan github.com >> /home/www-data/.ssh/known_hosts \
    && ssh-keyscan gitee.com >> /home/www-data/.ssh/known_hosts \
    && chown www-data:www-data /home/www-data/.ssh/known_hosts \
    && chmod 644 /home/www-data/.ssh/known_hosts

# 健康检测配置
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

EXPOSE ${APP_PORT} ${OCTANE_ADMIN_PORT} 9103 9201

WORKDIR $APP_PATH

USER www-data
CMD ["/usr/local/bin/startup.sh"]
