ARG POSTGRES_VERSION=18.1-trixie
FROM postgres:${POSTGRES_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ARG CHANGE_SOURCE=true

# 切换镜像源 (Debian Trixie)
RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 添加 PostgreSQL 官方仓库
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update

# 安装扩展（全部来自 apt，无需编译）
RUN apt-get install -y --no-install-recommends \
    # 核心扩展
    postgresql-18-postgis-3 \
    postgresql-18-pgvector \
    postgresql-18-timescaledb \
    postgresql-18-cron \
    # 其他工具
    tzdata \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 设置系统时区
RUN ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo ${TIMEZONE} > /etc/timezone

# 复制优化后的配置文件
COPY postgresql.conf /etc/postgresql/postgresql.conf

# 复制扩展初始化脚本
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/

# 设置环境变量
ENV POSTGRES_CONFIG_FILE=/etc/postgresql/postgresql.conf
ENV TZ=${TIMEZONE}

# 使用原始入口点，通过 CMD 传递配置参数
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}

EXPOSE 5432
