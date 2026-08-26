ARG POSTGRES_VERSION=18.6-trixie
FROM postgres:${POSTGRES_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ARG CHINA=true

# 切换镜像源 (Debian Trixie)
RUN if [ "$CHINA" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 添加 PostgreSQL 官方 PGDG 仓库
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    && curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 定义扩展版本参数（Debian 13 / trixie 对应 PGDG 构建后缀 pgdg13+1）
ARG PGCRON_VERSION=1.6.7-3.pgdg13+1
ARG POSTGIS_VERSION=3.6.4+dfsg-2.pgdg13+1
ARG PGVECTOR_VERSION=0.8.6-1.pgdg13+1
ARG AGE_VERSION=1.8.0~rc0-2.pgdg13+1
ARG PGVECTORSCALE_VERSION=0.9.0

# 安装扩展：
# 1. PostGIS: 空间地理信息支持
# 2. pgvector (https://github.com/pgvector/pgvector): 向量数据库基础扩展
# 3. pg_cron: 数据库定时任务调度
# 4. Apache AGE (https://github.com/apache/age/releases/tag/PG18%2Fv1.8.0-rc0): openCypher 图数据库支持
# 5. pgvectorscale (https://github.com/timescale/pgvectorscale/releases/tag/0.9.0): Timescale 向量加速扩展 (DiskANN + SBQ)
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-18-postgis-3="${POSTGIS_VERSION}" \
    postgresql-18-pgvector="${PGVECTOR_VERSION}" \
    postgresql-18-cron="${PGCRON_VERSION}" \
    postgresql-18-age="${AGE_VERSION}" \
    tzdata \
    && ARCH="$(dpkg --print-architecture)" \
    && curl -fSsL "https://github.com/timescale/pgvectorscale/releases/download/${PGVECTORSCALE_VERSION}/pgvectorscale-${PGVECTORSCALE_VERSION}-pg18-${ARCH}.zip" -o /tmp/pgvectorscale.zip \
    && unzip /tmp/pgvectorscale.zip -d /tmp/pgvectorscale \
    && dpkg -i "/tmp/pgvectorscale/pgvectorscale-postgresql-18_${PGVECTORSCALE_VERSION}-Linux_${ARCH}.deb" \
    && rm -rf /tmp/pgvectorscale* \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 设置系统时区
RUN ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo ${TIMEZONE} > /etc/timezone

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
