ARG POSTGRES_VERSION=18.4-alpine3.24
FROM postgres:${POSTGRES_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 定义扩展版本参数
ARG PGCRON_VERSION=1.6.7-r0
ARG POSTGIS_VERSION=3.6.3-r0
ARG PGVECTOR_VERSION=0.8.1-r0

# 安装扩展（PostGIS / pgvector / pg_cron）
# edge/community 仓库提供 Alpine 上最新的 PostgreSQL 扩展包
RUN apk add --no-cache \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
    postgis=${POSTGIS_VERSION} \
    postgresql-pgvector=${PGVECTOR_VERSION} \
    postgresql-pg_cron=${PGCRON_VERSION}

# 复制优化后的配置文件
COPY postgresql.conf /etc/postgresql/postgresql.conf

# 复制扩展初始化脚本
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/

# 设置环境变量
ENV POSTGRES_CONFIG_FILE=/etc/postgresql/postgresql.conf

# 使用原始入口点，通过 CMD 传递配置参数
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}

EXPOSE 5432
