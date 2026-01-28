FROM henrygd/beszel-agent:latest

# ============================================
# 环境变量配置
# ============================================
ENV LISTEN=45876 \
    KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7U3WmswR2GGyV/Q8MA2MPD/toJ9/9F2phZ/CgRgERE' \
    TOKEN=f8584037-db71-49ec-b14c-8ccd4e25b8ce \
    HUB_URL=http://beszel:8090 \
    DOCKER_HOST=tcp://docker-socket-proxy:2375

# ============================================
# 端口暴露
# ============================================
EXPOSE ${LISTEN}

# ============================================
# 健康检查
# ============================================
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD ["/agent", "health"]
