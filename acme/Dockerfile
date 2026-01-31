FROM neilpang/acme.sh:3.1.2

LABEL maintainer="seaside <531773730@qq.com>"

# 安装依赖 (curl, openssl 等已包含在基础镜像中)
# 如果需要特定的工具，可以在这里安装

COPY startup.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
