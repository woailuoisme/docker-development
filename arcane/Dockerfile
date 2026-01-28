FROM ghcr.io/getarcaneapp/arcane:latest

# ============================================
# 环境变量配置
# ============================================
ENV PUID=1000 \
    PGID=1000 \
    ANALYTICS_DISABLED=true \
    DOCKER_HOST=tcp://docker-socket-proxy:2375 \
    ENCRYPTION_KEY=X+WLo5fmQfruZm4N9tiFzbqSw1c8iIA3f8oL+1XfFhE= \
    JWT_SECRET=X+S26dlPE8oALJUb1oBj15BPKHTvklbONAYhITrAeIU=

# ============================================
# 端口暴露
# ============================================
EXPOSE 3552


# ============================================
# 健康检查
# ============================================
HEALTHCHECK --interval=10s --timeout=3s --retries=5 --start-period=15s \
    CMD curl -fsS http://localhost:3552/api/health >/dev/null || exit 1
