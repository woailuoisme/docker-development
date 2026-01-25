ARG TELEGRAF_VERSION=1.37
FROM telegraf:${TELEGRAF_VERSION}

ARG CHANGE_SOURCE=false
ARG TIMEZONE=Asia/Shanghai
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories; \
    fi && \
    apk add --no-cache tzdata && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone

# 复制主配置文件
COPY telegraf.toml /etc/telegraf/telegraf.toml

# 创建配置目录并复制所有配置文件
RUN mkdir -p /etc/telegraf/telegraf.d
COPY telegraf.d/ /etc/telegraf/telegraf.d/

# 为所有 .toml 文件创建 .conf 软链接（--config-directory 只识别 .conf 文件）
RUN cd /etc/telegraf/telegraf.d && \
    for f in *.toml; do \
    ln -s "$f" "${f%.toml}.conf"; \
    done

# 设置工作目录
WORKDIR /etc/telegraf

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=10s \
    CMD telegraf --test --config /etc/telegraf/telegraf.toml --config-directory /etc/telegraf/telegraf.d || exit 1

# 启动 Telegraf 并指定配置文件和配置目录
CMD ["telegraf", "--config", "/etc/telegraf/telegraf.toml", "--config-directory", "/etc/telegraf/telegraf.d"]


