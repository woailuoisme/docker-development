ARG POSTGRES_VERSION=18.1-alpine3.23
FROM postgres:${POSTGRES_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ARG CHANGE_SOURCE=true

RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

RUN apk update && apk add --no-cache \
    postgresql-pgvector \
    postgresql-timescaledb \
    postgis \
    geos \
    proj \
    gdal \
    sfcgal \
    tzdata \
    && mkdir -p /usr/local/share/postgresql/extension \
    && mkdir -p /usr/local/lib/postgresql \
    && ln -sf /usr/share/postgresql18/extension/* /usr/local/share/postgresql/extension/ \
    && ln -sf /usr/lib/postgresql18/*.so /usr/local/lib/postgresql/ \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && apk del tzdata

# 复制优化后的配置文件
COPY postgresql.conf /etc/postgresql/postgresql.conf

# 设置 PostgreSQL 使用自定义配置
ENV POSTGRES_CONFIG_FILE=/etc/postgresql/postgresql.conf
ENV TZ=${TIMEZONE}

# 使用原始入口点，通过 CMD 传递配置参数
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}

EXPOSE 5432
