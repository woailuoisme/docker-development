FROM alpine:latest

LABEL maintainer="seaside <531773730@qq.com>"

# 安装 mkcert 和必要的依赖
# mkcert 需要 nss-tools 来支持 Firefox (可选) 和 openssl
RUN apk add --no-cache \
    mkcert \
    nss-tools \
    openssl \
    ca-certificates

# 设置工作目录
WORKDIR /app

# 复制生成脚本
COPY generate.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
