# syntax=docker/dockerfile:1
ARG NGINX_VERSION=1.29.4
FROM buildpack-deps:trixie AS builder

ARG NGINX_VERSION
WORKDIR /usr/src

# 1. 安装构建依赖 (包含 zstd 和 brotli 所需库)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libpcre2-dev \
    libzstd-dev \
    libbrotli-dev

# 2. 下载源码并编译模块 (Zstd + Brotli)
RUN wget -qO- http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xz && \
    git clone --depth 1 https://github.com/tokers/zstd-nginx-module.git && \
    git clone --depth 1 --recursive https://github.com/google/ngx_brotli.git && \
    cd nginx-${NGINX_VERSION} && \
    ./configure --with-compat \
    --add-dynamic-module=../zstd-nginx-module \
    --add-dynamic-module=../ngx_brotli && \
    make -j$(nproc) modules

ARG NGINX_TAG_SUFFIX=trixie
# 最终运行时镜像
FROM nginx:${NGINX_VERSION}-${NGINX_TAG_SUFFIX}

LABEL maintainer="seaside <seaside@qq.com>"

# 安装运行时必需的共享库
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    libzstd1 \
    libbrotli1 && \
    rm -rf /var/lib/apt/lists/*

# 集中复制所有编译好的 .so 模块
# ngx_http_zstd_filter_module.so, ngx_http_zstd_static_module.so, 
# ngx_http_brotli_filter_module.so, ngx_http_brotli_static_module.so
COPY --from=builder /usr/src/nginx-${NGINX_VERSION}/objs/ngx_http_zstd_*.so /usr/lib/nginx/modules/
COPY --from=builder /usr/src/nginx-${NGINX_VERSION}/objs/ngx_http_brotli_*.so /usr/lib/nginx/modules/

STOPSIGNAL SIGQUIT

# 提示：需在 nginx.conf 顶部加载
# load_module modules/ngx_http_zstd_filter_module.so;
# load_module modules/ngx_http_zstd_static_module.so;
# load_module modules/ngx_http_brotli_filter_module.so;
# load_module modules/ngx_http_brotli_static_module.so;