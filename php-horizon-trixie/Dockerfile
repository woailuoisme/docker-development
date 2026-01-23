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
    ENABLE_SUPERVISOR=true \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

# 切换镜像源 (Debian Trixie)
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 设置系统时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


COPY config/*.ini /usr/local/etc/php/conf.d/

# 安装 supervisor (Debian Trixie)
#RUN apt-get update && apt-get install -y --no-install-recommends \
#    procps iproute2 iputils-ping lsof psmisc vim-tiny supervisor && \

RUN rm -rf /var/lib/apt/lists/*

# 创建必要的 supervisor 目录
RUN mkdir -p /var/log/supervisor /var/run /usr/local/etc/supervisord.d && \
    chown -R www-data:www-data /var/log/supervisor /var/run /usr/local/etc/supervisord.d

# 复制 supervisor 主配置文件
COPY supervisord.conf /usr/local/etc/supervisord.conf

# 复制启动脚本和健康检查脚本
COPY startup.sh /usr/local/bin/startup.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

USER www-data
# 使用 startup.sh 脚本启动服务
CMD ["/usr/local/bin/startup.sh"]

# 修复健康检查：检查 Horizon 进程而不是 supervisord
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

WORKDIR $APP_PATH