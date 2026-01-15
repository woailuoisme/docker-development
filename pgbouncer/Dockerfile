FROM alpine:3.23
LABEL maintainer="seaside <531773730@qq.com>"

ARG CHANGE_SOURCE=false
ARG TIMEZONE=Asia/Shanghai

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
ENV PGBOUNCER_EXTRA_USERS=""

# 连接池配置
ENV MAX_CLIENT_CONN=200 \
    DEFAULT_POOL_SIZE=25 \
    MIN_POOL_SIZE=5 \
    RESERVE_POOL_SIZE=5 \
    MAX_DB_CONNECTIONS=50 \
    MAX_USER_CONNECTIONS=50

# 超时配置（秒）
ENV QUERY_WAIT_TIMEOUT=120 \
    SERVER_IDLE_TIMEOUT=600 \
    SERVER_LIFETIME=3600

# 日志配置
ENV LOG_CONNECTIONS=1 \
    LOG_DISCONNECTIONS=1 \
    VERBOSE=0

# ============================================================================
# 系统配置
# ============================================================================

# 更换镜像源（可选）
RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

# 安装 pgbouncer 和必要工具
RUN apk add --no-cache \
    pgbouncer \
    postgresql-client \
    tzdata \
    bash \
    curl \
    netcat-openbsd \
    gettext \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && apk del tzdata

# 创建非 root 用户和必要目录
RUN addgroup -S pgbouncer && adduser -S pgbouncer -G pgbouncer \
    && mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer \
    && chown -R pgbouncer:pgbouncer /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer

# 复制配置模板文件
COPY --chown=pgbouncer:pgbouncer pgbouncer.envsubst.ini /etc/pgbouncer/pgbouncer.envsubst.ini
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
CMD ["pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
