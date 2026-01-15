ARG REDIS_VERSION=8.4-alpine
FROM redis:${REDIS_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG CHANGE_SOURCE=true
ENV TIMEZONE=Asia/Shanghai

RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

RUN apk update && apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    apk del tzdata

RUN mkdir -p /usr/local/etc/redis
COPY redis.conf /usr/local/etc/redis/redis.conf

VOLUME /data

EXPOSE 6379

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD redis-cli ping || exit 1

CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
