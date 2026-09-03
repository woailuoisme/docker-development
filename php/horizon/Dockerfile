#FROM ccr.ccs.tencentyun.com/jiaoio/php-base-simple-cli
#FROM quay.io/jiaoio/php-base-simple-cli
#FROM jiaoio/php-base-simple-cli
#FROM jiaoio/php-base-simple-cli:8.5-cli-latest
ARG PHP_VERSION=8.5
FROM jiaoio/php${PHP_VERSION}:cli-alpine


ARG CHANGE_SOURCE=true

ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    TZ=Asia/Shanghai \
    CHANGE_SOURCE=${CHANGE_SOURCE} \
    ENABLE_SUPERVISOR=true \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

# 切换镜像源 (Alpine)
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi


# 设置系统时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


COPY config/*.ini /usr/local/etc/php/conf.d/

# 安装 supervisor (Alpine)
#RUN apk update && apk add --no-cache \
#    procps iproute2 iputils ping lsof psmisc vim supervisor


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
    CMD ["sh", "-c", "/usr/local/bin/healthcheck.sh"]

WORKDIR $APP_PATH