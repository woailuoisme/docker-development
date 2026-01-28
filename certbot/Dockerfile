#ARG CERTBOT_VERSION=v5.2.2
ARG CERTBOT_VERSION=latest
FROM certbot/certbot:${CERTBOT_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

# 安装阿里云和 Cloudflare DNS 插件
RUN pip install certbot-dns-cloudflare certbot-dns-aliyun && \
    apk add --no-cache netcat-openbsd

# 创建必要的目录
RUN mkdir -p /etc/letsencrypt

# 设置工作目录
WORKDIR /opt/certbot

# 复制启动脚本和健康检查脚本
COPY startup.sh /opt/certbot/startup.sh
COPY healthcheck.sh /opt/certbot/healthcheck.sh
RUN chmod +x /opt/certbot/startup.sh /opt/certbot/healthcheck.sh

# 设置入口点和健康检查
ENTRYPOINT ["/opt/certbot/startup.sh"]
#HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
#    CMD /opt/certbot/healthcheck.sh check
