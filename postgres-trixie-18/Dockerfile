ARG POSTGRES_VERSION=18.1-trixie

# ==========================================
# 阶段 1: 构建器 (builder) - 使用官方 Rust 镜像加快速度
# ==========================================
FROM rust:1.93-slim-trixie AS builder

ARG CHANGE_SOURCE=true

# 切换镜像源 (Debian Trixie)
RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 配置 Cargo 使用国内镜像源 (rsproxy.cn) 加速构建
RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    mkdir -p $CARGO_HOME \
    && echo "[source.crates-io]" > $CARGO_HOME/config.toml \
    && echo "replace-with = 'rsproxy-sparse'" >> $CARGO_HOME/config.toml \
    && echo "[source.rsproxy]" >> $CARGO_HOME/config.toml \
    && echo "registry = 'https://rsproxy.cn/crates.io-index'" >> $CARGO_HOME/config.toml \
    && echo "[source.rsproxy-sparse]" >> $CARGO_HOME/config.toml \
    && echo "registry = 'sparse+https://rsproxy.cn/index/'" >> $CARGO_HOME/config.toml \
    && echo "[registries.rsproxy]" >> $CARGO_HOME/config.toml \
    && echo "index = 'https://rsproxy.cn/crates.io-index'" >> $CARGO_HOME/config.toml \
    && echo "[net]" >> $CARGO_HOME/config.toml \
    && echo "git-fetch-with-cli = true" >> $CARGO_HOME/config.toml; \
    fi

# 安装编译所需的系统依赖
# 注意：必需安装 postgresql-server-dev-18 以获取 pg_config
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    lsb-release \
    wget \
    gnupg \
    python3-dev \
    && curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends postgresql-server-dev-18 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 1. 编译并安装 pgai (Timescale)
# pgvectorscale 需要 pgrx 0.16.1
ARG PGAI_VERSION=main
RUN cargo install cargo-pgrx --version 0.16.1 --locked \
    && cargo pgrx init --pg18 /usr/lib/postgresql/18/bin/pg_config \
    && mkdir -p /tmp/pgai \
    && curl -fSsL https://github.com/timescale/pgai/archive/refs/heads/${PGAI_VERSION}.tar.gz -o /tmp/pgai.tar.gz \
    && tar -xzf /tmp/pgai.tar.gz -C /tmp/pgai --strip-components=1 \
    && cd /tmp/pgai/projects/extension \
    && cargo pgrx install --release

# 2. 编译并安装 pgvectorscale (Timescale)
ARG PGVECTORSCALE_VERSION=main
RUN mkdir -p /tmp/pgvectorscale \
    && curl -fSsL https://github.com/timescale/pgvectorscale/archive/refs/heads/${PGVECTORSCALE_VERSION}.tar.gz -o /tmp/pgvectorscale.tar.gz \
    && tar -xzf /tmp/pgvectorscale.tar.gz -C /tmp/pgvectorscale --strip-components=1 \
    && cd /tmp/pgvectorscale/pgvectorscale \
    && cargo pgrx install --release

# ==========================================
# 阶段 2: 最终运行环境 (final)
# ==========================================
FROM postgres:${POSTGRES_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ARG CHANGE_SOURCE=true

# 切换镜像源 (Debian Trixie)
RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 安装运行时依赖和官方仓库扩展
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-18-postgis-3 \
    postgresql-18-pgvector \
    postgresql-18-timescaledb \
    postgresql-18-cron \
    postgresql-plpython3-18 \
    python3 \
    tzdata \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 从构建器中复制编译好的扩展文件
# 包括 .so 库文件和 .control/.sql 定义文件
COPY --from=builder /usr/lib/postgresql/18/lib/ /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/ /usr/share/postgresql/18/extension/

# 设置系统时区
RUN ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo ${TIMEZONE} > /etc/timezone

# 复制优化后的配置文件
COPY postgresql.conf /etc/postgresql/postgresql.conf

# 设置环境变量
ENV POSTGRES_CONFIG_FILE=/etc/postgresql/postgresql.conf
ENV TZ=${TIMEZONE}

# 使用原始入口点，通过 CMD 传递配置参数
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}

EXPOSE 5432
