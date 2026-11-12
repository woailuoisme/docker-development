# PHP 8.5 Base RoadRunner Alpine Image
# ============================================================================
FROM ghcr.io/roadrunner-server/roadrunner:3.0 AS roadrunner

FROM jiaoio/php8.5:cli
LABEL maintainer="seaside <531773730@qq.com>"

# 直接复用官方镜像中的 rr 二进制（Alpine/musl 构建，无需 gcompat）
COPY --from=roadrunner /usr/bin/rr /usr/local/bin/rr

# 校验二进制可执行
RUN set -eux; \
    chmod +x /usr/local/bin/rr; \
    rr --version
