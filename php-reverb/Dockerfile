#FROM ccr.ccs.tencentyun.com/jiaoio/php-base-simple-cli
#FROM jiaoio/php-base-simple-cli
FROM jiaoio/php-base-simple-cli:8.5-cli-latest

ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=production \
    REVERB_DEBUG=true \
    CHANGE_SOURCE=true \
    ENABLE_SUPERVISOR=false \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

RUN if [ ${CHANGE_SOURCE} = true ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories; \
    fi

# 安装 supervisor (Alpine Linux)
RUN apk update && apk add --no-cache supervisor && \
    rm -rf /var/cache/apk/*

# 创建必要的 supervisor 目录
RUN mkdir -p /var/log/supervisor && \
    mkdir -p /var/run && \
    mkdir -p /usr/local/etc/supervisord.d

# 复制 supervisor 主配置文件
COPY supervisord.conf /usr/local/etc/supervisord.conf

COPY config/*.ini /usr/local/etc/php/conf.d/

# 复制启动脚本
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

USER www-data
# 使用 startup.sh 脚本启动服务
CMD ["/usr/local/bin/startup.sh"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD ps -eo pid,comm,args | grep -q "[p]hp.*artisan.*reverb" || exit 1
