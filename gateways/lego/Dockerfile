ARG LEGO_VERSION=v5
FROM goacme/lego:${LEGO_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

# 设置系统时区并安装必要工具包
ENV TZ=Asia/Shanghai

RUN apk add --no-cache \
    bash \
    curl \
    tzdata \
    ca-certificates && \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    echo "${TZ}" > /etc/timezone

WORKDIR /lego

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
