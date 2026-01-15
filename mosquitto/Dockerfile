FROM eclipse-mosquitto:2.0.22-openssl

ARG CHANGE_SOURCE=false
ARG TIMEZONE=Asia/Shanghai
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories; \
    fi && \
    apk add --no-cache tzdata && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone \

    ENV DEV=true

COPY config/*.conf /mosquitto/config

COPY startup.sh /usr/local/bin/startup.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x /usr/local/bin/startup.sh && \
    chmod +x /usr/local/bin/healthcheck.sh

# 健康检查（支持认证）
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# 设置启动命令
ENTRYPOINT ["/usr/local/bin/startup.sh"]

CMD ["mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
