ARG MYSQL_VERSION=8.4
FROM mysql:${MYSQL_VERSION}

LABEL maintainer="Seaside"

# 设置系统时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 健康检查
HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=30s \
    CMD mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD}
