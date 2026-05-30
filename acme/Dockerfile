ARG ACME_VERSION=3.1.3
FROM neilpang/acme.sh:${ACME_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

# 安装依赖 (curl, openssl 等已包含在基础镜像中)
# 如果需要特定的工具，可以在这里安装

COPY startup.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
