#FROM jiaoio/php-base-roadrunner-trixie
#FROM jiaoio/php-base-roadrunner
FROM jiaoio/php-base-roadrunner:8.5-latest
#FROM jiaoio/php-base-cli
## 安装 RoadRunner - 使用自定义脚本下载、解压并安装到 /usr/local/bin
#COPY download_roadrunner.sh /tmp/download_roadrunner.sh
#RUN chmod +x /tmp/download_roadrunner.sh && \
#    /tmp/download_roadrunner.sh && \
#    rm /tmp/download_roadrunner.sh

ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    APP_DEBUG=false \
    ENABLE_SUPERVISOR=false \
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

# 复制PHP配置
COPY config/*.ini /usr/local/etc/php/conf.d/

# 复制启动脚本
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# 复制健康检查脚本
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# 创建必要的 supervisor 目录
RUN mkdir -p /usr/local/etc/supervisord.d

# 复制 Supervisor 主配置文件
COPY supervisord.conf /usr/local/etc/supervisord.conf

# 健康检测配置
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

EXPOSE ${APP_PORT} 6001
WORKDIR $APP_PATH
USER www-data
CMD ["/usr/local/bin/startup.sh"]

