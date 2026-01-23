ARG PHP_VERSION=8.5
FROM jiaoio/php-base-simple-cli-trixie:${PHP_VERSION}-cli-latest

ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    TZ=Asia/Shanghai \
    SENTRY_DSN='' \
    SENTRY_ENVIRONMENT='' \
    SENTRY_RELEASE='' \
    MAGICK_THREAD_LIMIT=2 \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

COPY config/*.ini /usr/local/etc/php/conf.d/

# 复制启动脚本
COPY startup.sh /usr/local/bin/startup.sh

# 设置权限（在切换用户之前）
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    chmod +x /usr/local/bin/startup.sh && \
    chown -R www-data:www-data /usr/local/bin/supercronic /usr/local/bin/startup.sh && \
    touch /usr/local/etc/laravel-cron && \
    chown www-data:www-data /usr/local/etc/laravel-cron && \
    chmod 644 /usr/local/etc/laravel-cron

USER www-data
# 使用 startup.sh 脚本启动服务
CMD ["/usr/local/bin/startup.sh"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/startup.sh healthcheck

WORKDIR $APP_PATH