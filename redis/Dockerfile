ARG REDIS_VERSION=8.4-bookworm
FROM redis:${REDIS_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG CHANGE_SOURCE=true
ENV TIMEZONE=Asia/Shanghai

# 切换镜像源 (Debian bookworm)
RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 配置时区
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata && \
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/etc/redis
COPY redis.conf /usr/local/etc/redis/redis.conf

VOLUME /data

EXPOSE 6379

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD redis-cli ping || exit 1

CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
