FROM alpine:3.24
LABEL maintainer="seaside <531773730@qq.com>"

# 构建参数
ARG CHANGE_SOURCE=false
ARG TIMEZONE=Asia/Shanghai

# ============================================================================
# PgBouncer 环境变量默认值
# ============================================================================

ENV POSTGRES_HOST=postgres \
    POSTGRES_PORT=5432 \
    POSTGRES_DB=lunchbox \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD="" \
    PGBOUNCER_ADMIN_USER="" \
    PGBOUNCER_ADMIN_PASSWORD="" \
    PGBOUNCER_EXTRA_USERS="" \
    TZ=${TIMEZONE}

# ============================================================================
# 系统配置
# ============================================================================

# 1. 切换镜像源 (Alpine 3.24)
RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

# 2. 安装 pgbouncer 和必要工具
RUN apk add --no-cache \
        pgbouncer \
        postgresql18-client \
        tzdata \
    && ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone

# 3. 创建非 root 用户、组和必要目录
RUN mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer \
    && addgroup -S pgbouncer 2>/dev/null || true \
    && adduser -S -G pgbouncer pgbouncer 2>/dev/null || true \
    && chown -R pgbouncer:pgbouncer /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer

# 4. 复制配置文件
COPY --chown=pgbouncer:pgbouncer pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY --chown=pgbouncer:pgbouncer entrypoint.sh /usr/local/bin/

# 设置执行权限
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 15432

# 优化的健康检查 - 使用 BusyBox nc
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD ["sh", "-c", "nc -z -w 2 127.0.0.1 15432 || exit 1"]

# 切换到非 root 用户
USER pgbouncer

# 使用 entrypoint 脚本启动
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
