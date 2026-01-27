ARG TELEGRAF_VERSION=1.37
FROM telegraf:${TELEGRAF_VERSION}

ARG CHANGE_SOURCE=false
ARG TIMEZONE=Asia/Shanghai
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
    fi && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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

# 健康检查 - 仅测试主配置文件以避免由于 MQTT Client ID 冲突导致的连接中断
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=10s \
    CMD telegraf --test --config /etc/telegraf/telegraf.toml --config-directory /etc/telegraf/telegraf.d || exit 1

# 启动 Telegraf 并指定配置文件和配置目录
CMD ["telegraf", "--non-strict-env-handling", "--config", "/etc/telegraf/telegraf.toml", "--config-directory", "/etc/telegraf/telegraf.d"]


