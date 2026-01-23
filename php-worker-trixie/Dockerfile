#FROM ccr.ccs.tencentyun.com/jiaoio/php-base-simple-cli
#FROM quay.io/jiaoio/php-base-simple-cli
#FROM jiaoio/php-base-simple-cli
#FROM jiaoio/php-base-simple-cli:8.5-cli-latest
ARG PHP_VERSION=8.5
FROM jiaoio/php-base-simple-cli-trixie:${PHP_VERSION}-cli-latest

ARG CHANGE_SOURCE=true

ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    TZ=Asia/Shanghai \
    CHANGE_SOURCE=${CHANGE_SOURCE} \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

# 切换镜像源 (Debian Trixie)
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 设置系统时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY config/*.ini /usr/local/etc/php/conf.d/

# 复制启动脚本和健康检查脚本
COPY startup.sh /usr/local/bin/startup.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

USER www-data
# 使用 startup.sh 脚本启动服务
CMD ["/usr/local/bin/startup.sh"]

# 健康检查：检查 Queue Worker 进程
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

WORKDIR $APP_PATH
