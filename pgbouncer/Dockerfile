FROM debian:trixie-slim
LABEL maintainer="seaside <531773730@qq.com>"

# 构建参数
ARG CHANGE_SOURCE=false
ARG TIMEZONE=Asia/Shanghai
# pgbouncer 1.25.1 版本号 (来自 PostgreSQL apt 仓库)
ARG PGBOUNCER_VERSION=1.25.1-1.pgdg13+1

# ============================================================================
# PgBouncer 环境变量默认值
# ============================================================================

# PostgreSQL 连接配置
ENV POSTGRES_HOST=postgres \
    POSTGRES_PORT=5432 \
    POSTGRES_DB=lunchbox \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=""

# PgBouncer 管理用户（可选，默认使用 POSTGRES_USER）
ENV PGBOUNCER_ADMIN_USER="" \
    PGBOUNCER_ADMIN_PASSWORD=""

# 额外用户（可选，格式：user1:pass1,user2:pass2）
ENV PGBOUNCER_EXTRA_USERS="" \
    TZ=${TIMEZONE}

# ============================================================================
# 系统配置
# ============================================================================

# 1. 切换镜像源 (Debian Trixie)
RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 2. 安装 pgbouncer 和必要工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    pgbouncer=${PGBOUNCER_VERSION} \
    postgresql-client-18 \
    tzdata \
    bash \
    netcat-openbsd \
    gettext-base \
    && ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. 创建非 root 用户和必要目录 (如果安装包没自动创建的话，强制设置权限)
RUN groupadd -r pgbouncer 2>/dev/null || true && \
    useradd -r -g pgbouncer pgbouncer 2>/dev/null || true \
    && mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer \
    && chown -R pgbouncer:pgbouncer /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer

# 4. 复制配置文件
COPY --chown=pgbouncer:pgbouncer pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY --chown=pgbouncer:pgbouncer entrypoint.sh /usr/local/bin/

# 设置执行权限
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 15432

# 优化的健康检查 - 使用 TCP 端口检查
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD nc -z 127.0.0.1 15432 || exit 1

# 切换到非 root 用户
USER pgbouncer

# 使用 entrypoint 脚本启动
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
