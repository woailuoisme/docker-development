ARG NGINX_VERSION=1.31-alpine
ARG CHANGE_SOURCE=true

FROM nginx:${NGINX_VERSION}

LABEL maintainer="seaside <seaside@qq.com>"

ARG CHANGE_SOURCE
ARG TIMEZONE=Asia/Shanghai

ENV TZ=${TIMEZONE}

# 1. 安装 Alpine 运行时实用工具、配置时区并创建 www-data 用户
RUN set -e; \
    if [ "${CHANGE_SOURCE}" = "true" ]; then \
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi; \
    apk add --no-cache \
        procps \
        curl \
        ca-certificates \
        gettext \
        openssl \
        bash \
        shadow \
        tzdata; \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime; \
    echo "${TIMEZONE}" > /etc/timezone; \
    if ! getent group www-data >/dev/null 2>&1; then groupadd -g 33 www-data; fi; \
    if ! getent passwd www-data >/dev/null 2>&1; then useradd -l -u 33 -g www-data -s /sbin/nologin www-data; fi

# 2. 预集成公共 Snippets (Security Headers & WAF)
COPY config/snippets /etc/nginx/snippets/

STOPSIGNAL SIGQUIT
