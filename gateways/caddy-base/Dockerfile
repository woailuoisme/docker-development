ARG CADDY_VERSION=2.11.4

# 阶段 1: 编译构建
FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

# 运行 xcaddy build 来构建，不需要指定核心模块，它们会自动包含。
RUN xcaddy build \
    --output /usr/bin/caddy \
    --with github.com/caddyserver/transform-encoder \
    --with github.com/mholt/caddy-l4@v0.1.2 \
    --with github.com/caddy-dns/cloudflare@v0.2.4 \
    --with github.com/caddy-dns/alidns@v1.0.29 \
    --with github.com/caddyserver/replace-response \
    --with github.com/caddyserver/cache-handler@v0.16.0 \
    --with github.com/mholt/caddy-ratelimit@v0.1.0 \
    --with github.com/sagikazarmark/caddy-fs-s3@v0.12.0 \
    --with github.com/corazawaf/coraza-caddy/v2@v2.6.1 \
    --with github.com/hslatman/caddy-crowdsec-bouncer/http@v0.14.1 \
    --with github.com/hslatman/caddy-crowdsec-bouncer/layer4@v0.14.1

# 阶段 2: 最终运行镜像
FROM caddy:${CADDY_VERSION}-alpine
LABEL maintainer="seaside <531773730@qq.com>"

ENV TZ=Asia/Shanghai

# 安装基础运行依赖并配置时区（前置以最大化利用构建层缓存）
RUN apk add --no-cache nss-tools tzdata curl && \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

# 替换官方的 caddy 可执行文件为我们构建的版本
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
