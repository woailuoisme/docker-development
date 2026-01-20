ARG MEILI_VERSION=v1.33
FROM getmeili/meilisearch:${MEILI_VERSION}

ARG TIMEZONE=Asia/Shanghai
ARG CHANGE_SOURCE=true

RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

RUN apk add --no-cache tzdata && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo ${TIMEZONE} > /etc/timezone

# 复制配置文件
COPY config.toml /meili_config/config.toml

HEALTHCHECK --interval=60s --timeout=10s --start-period=60s --retries=5 \
    CMD wget --spider -q http://127.0.0.1:7700/health || exit 1
