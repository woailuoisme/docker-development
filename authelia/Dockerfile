ARG AUTHELA_VERSION=4.39
FROM authelia/authelia:${AUTHELA_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

# 复制配置文件
COPY ./config/configuration.yml /config/configuration.yml
COPY ./config/users_database.yml /config/users_database.yml
# 创建通知文件
RUN touch /config/notification.txt

# 暴露端口
EXPOSE 9091

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9091/api/health || exit 1