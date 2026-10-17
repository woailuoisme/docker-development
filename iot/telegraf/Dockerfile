ARG TELEGRAF_VERSION=1.40-alpine
FROM telegraf:${TELEGRAF_VERSION}

ARG TZ=Asia/Shanghai
RUN apk add --no-cache tzdata procps && \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    echo "${TZ}" > /etc/TZ

COPY telegraf.toml /etc/telegraf/telegraf.toml

# 创建配置目录并复制所有配置文件
RUN mkdir -p /etc/telegraf/telegraf.d
COPY telegraf.d/ /etc/telegraf/telegraf.d/

# 为所有 .toml 文件创建 .conf 软链接（--config-directory 只识别 .conf 文件）
WORKDIR /etc/telegraf/telegraf.d
RUN for f in *.toml; do \
    ln -s "$f" "${f%.toml}.conf"; \
    done

WORKDIR /etc/telegraf

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD ["sh", "-c", "pgrep telegraf || exit 1"]

# 启动 Telegraf 并指定配置文件和配置目录
CMD ["telegraf", "--non-strict-env-handling", "--config", "/etc/telegraf/telegraf.toml", "--config-directory", "/etc/telegraf/telegraf.d"]
