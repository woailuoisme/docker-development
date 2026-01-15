ARG MONGO_VERSION=8.0
FROM mongo:${MONGO_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ENV TZ=${TIMEZONE}

# 安装必要工具 (可选)
# RUN apt-get update && apt-get install -y iputils-ping && rm -rf /var/lib/apt/lists/*

# 复制配置文件 (可选)
COPY mongod.conf /etc/mongod.conf

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 如果需要使用自定义配置，可以取消下面注释
CMD ["mongod", "--config", "/etc/mongod.conf"]

# 设置健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD mongosh --eval 'db.runCommand({ connectionStatus: 1 })'

EXPOSE 27017
