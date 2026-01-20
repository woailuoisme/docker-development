FROM jiaoio/php-base-roadrunner-trixie:2025.1.6-php8.5

ARG CHANGE_SOURCE=true

ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    APP_DEBUG=false \
    TZ=Asia/Shanghai \
    CHANGE_SOURCE=${CHANGE_SOURCE} \
    OCTANE_RR_BINARY=/usr/local/bin/rr \
    OCTANE_SERVER=roadrunner \
    OCTANE_HOST=0.0.0.0 \
    OCTANE_WORKERS=4 \
    OCTANE_MAX_REQUESTS=500 \
    OCTANE_LOG_LEVEL=info \
    WATCH=false \
    COMPOSER_ALLOW_SUPERUSER=1 \
    MAGICK_THREAD_LIMIT=2 \
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

# 健康检测配置
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

EXPOSE ${APP_PORT} 6001
WORKDIR $APP_PATH
USER www-data
CMD ["/usr/local/bin/startup.sh"]
