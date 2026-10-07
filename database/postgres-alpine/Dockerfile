ARG POSTGRES_VERSION=18.6-alpine3.24
FROM postgres:${POSTGRES_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ARG CHINA=false

# 切换镜像源 (Alpine Linux)
RUN if [ "$CHINA" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

# 安装运行时依赖与预编译官方扩展 (postgis, pgvector, pg_cron)
# 通过 Alpine 官方 community 仓库预编译包安装，无需拉取编译工具链源码编译
RUN apk add --no-cache \
    bash \
    tzdata \
    musl-locales \
    postgis \
    postgresql-pgvector \
    postgresql-pg_cron \
    && for dir in /usr/lib/postgresql18 /usr/lib/postgresql; do \
        if [ -d "$dir" ]; then \
            ln -sf "$dir"/*.so /usr/local/lib/postgresql/ 2>/dev/null || true; \
        fi; \
    done \
    && for dir in /usr/share/postgresql18/extension /usr/share/postgresql/extension; do \
        if [ -d "$dir" ]; then \
            ln -sf "$dir"/* /usr/local/share/postgresql/extension/ 2>/dev/null || true; \
        fi; \
    done

# 设置系统时区
RUN cp "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && echo "${TIMEZONE}" > /etc/timezone

# 复制优化后的配置文件
COPY postgresql.conf /etc/postgresql/postgresql.conf

# 复制扩展初始化脚本
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/

# 设置环境变量
ENV POSTGRES_CONFIG_FILE=/etc/postgresql/postgresql.conf

# 使用原始入口点，通过 CMD 传递配置参数
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

HEALTHCHECK --interval=60s --timeout=10s --retries=5 --start-period=60s \
    CMD ["sh", "-c", "pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}"]

EXPOSE 5432
