FROM alpine:3.23

ARG PB_VERSION=0.36.7

# 设置默认管理员凭据
ENV PB_ADMIN_EMAIL=admin@admin.com
ENV PB_ADMIN_PASSWORD=1234567890

RUN apk add --no-cache \
    unzip \
    ca-certificates \
    wget

# 下载并解压 PocketBase (保留自动检测架构，兼容 Mac M 系列芯片)
RUN if [ "$(uname -m)" = "x86_64" ]; then \
    ARCH="amd64"; \
    else \
    ARCH="arm64"; \
    fi && \
    wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${ARCH}.zip" -O /tmp/pb.zip && \
    unzip /tmp/pb.zip -d /pb/ && \
    rm /tmp/pb.zip

WORKDIR /pb

# 复制初始化脚本
COPY init.sh ./init.sh
RUN chmod +x ./init.sh

EXPOSE 8090

# 启动脚本：先执行初始化创建管理员，再启动 PocketBase
CMD ["/bin/sh", "-c", "./init.sh && ./pocketbase serve --http=0.0.0.0:8090"]
