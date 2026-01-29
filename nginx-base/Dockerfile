# syntax=docker/dockerfile:1
ARG NGINX_VERSION=1.29.4-trixie
FROM buildpack-deps:trixie AS builder

ARG NGINX_VERSION
WORKDIR /usr/src

# 1. 安装构建依赖 (排除 buildpack-deps 已有的基础工具)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libpcre2-dev \
    libzstd-dev \
    libbrotli-dev

# 2. 下载源码并编译模块 (Zstd + Brotli)
RUN NGINX_PURE_VERSION=${NGINX_VERSION%-*} && \
    wget -qO- http://nginx.org/download/nginx-${NGINX_PURE_VERSION}.tar.gz | tar xz && \
    ln -s nginx-${NGINX_PURE_VERSION} nginx-src && \
    git clone --depth 1 https://github.com/tokers/zstd-nginx-module.git && \
    git clone --depth 1 --recursive https://github.com/google/ngx_brotli.git && \
    cd nginx-src && \
    ./configure --with-compat \
    --add-dynamic-module=../zstd-nginx-module \
    --add-dynamic-module=../ngx_brotli && \
    make -j$(nproc) modules

# 最终运行时镜像
FROM nginx:${NGINX_VERSION}

LABEL maintainer="seaside <seaside@qq.com>"

ARG NGINX_VERSION

# 安装运行时必需的共享库
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    libzstd1 libbrotli1 \
    procps curl ca-certificates gettext openssl bash && \
    rm -rf /var/lib/apt/lists/*

# 集中复制所有编译好的 .so 模块
COPY --from=builder /usr/src/nginx-src/objs/ngx_http_zstd_*.so /usr/lib/nginx/modules/
COPY --from=builder /usr/src/nginx-src/objs/ngx_http_brotli_*.so /usr/lib/nginx/modules/

STOPSIGNAL SIGQUIT

# 提示：需在 nginx.conf 顶部加载
# load_module modules/ngx_http_zstd_filter_module.so;
# load_module modules/ngx_http_brotli_filter_module.so;