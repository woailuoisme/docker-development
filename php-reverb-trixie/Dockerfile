#FROM ccr.ccs.tencentyun.com/jiaoio/php-base-simple-cli
#FROM jiaoio/php-base-simple-cli
#FROM jiaoio/php-base-simple-cli:8.5-cli-latest
FROM jiaoio/php-base-simple-cli-trixie:8.5-cli-latest


ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    REVERB_DEBUG=true \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

COPY config/*.ini /usr/local/etc/php/conf.d/

# 复制启动脚本和健康检查脚本
COPY startup.sh /usr/local/bin/startup.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

USER www-data
# 使用 startup.sh 脚本启动服务
CMD ["/usr/local/bin/startup.sh"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

WORKDIR $APP_PATH