ARG POSTGRES_VERSION=17.7-alpine3.23
FROM postgres:${POSTGRES_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ARG CHANGE_SOURCE=true

# 环境变量默认值
ENV POSTGRES_CONFIG_PROFILE=1c1g

RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

# 定义扩展版本参数 (基于 Alpine 3.23/edge 最新版)
ARG POSTGIS_VERSION=3.6.1-r0
ARG PGVECTOR_VERSION=0.8.1-r0
ARG TIMESCALEDB_VERSION=2.23.0-r1
ARG PGCRON_VERSION=1.6.7-r0

RUN apk update && apk add --no-cache \
    postgresql-pgvector=${PGVECTOR_VERSION} \
    postgresql-timescaledb=${TIMESCALEDB_VERSION} \
    postgresql-pg_cron=${PGCRON_VERSION} \
    postgis=${POSTGIS_VERSION} \
    geos \
    proj \
    gdal \
    sfcgal \
    tzdata \
    bash \
    && mkdir -p /usr/local/share/postgresql/extension \
    && mkdir -p /usr/local/lib/postgresql \
    && ln -sf /usr/share/postgresql17/extension/* /usr/local/share/postgresql/extension/ \
    && ln -sf /usr/lib/postgresql17/*.so /usr/local/lib/postgresql/ \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && apk del tzdata

# 创建配置目录
RUN mkdir -p /etc/postgresql && \
    chown -R postgres:postgres /etc/postgresql

# 复制所有配置文件
COPY postgresql.conf /etc/postgresql/postgresql.conf
COPY postgresql-2c2g.conf /etc/postgresql/postgresql-2c2g.conf
COPY postgresql-4c8g.conf /etc/postgresql/postgresql-4c8g.conf

# 复制自定义 entrypoint
COPY docker-entrypoint.sh /usr/local/bin/postgres-entrypoint.sh
RUN chmod +x /usr/local/bin/postgres-entrypoint.sh

# 使用自定义 entrypoint
ENTRYPOINT ["/usr/local/bin/postgres-entrypoint.sh"]

# 健康检查
HEALTHCHECK --interval=60s --timeout=10s --retries=5 --start-period=60s \
    CMD pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}

EXPOSE 5432
