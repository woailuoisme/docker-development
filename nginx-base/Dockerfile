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
    libbrotli-dev \
    libgeoip-dev \
    libgd-dev \
    libperl-dev \
    liblmdb-dev \
    liblua5.3-dev \
    flex \
    bison

# 2. 编译 ModSecurity 核心库 (v3)
RUN git clone --depth 1 -b v3/master https://github.com/owasp-modsecurity/ModSecurity && \
    cd ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install

# 3. 下载并编译 Nginx 模块 (Zstd + Brotli + ModSecurity)
RUN NGINX_PURE_VERSION=${NGINX_VERSION%-*} && \
    wget -qO- http://nginx.org/download/nginx-${NGINX_PURE_VERSION}.tar.gz | tar xz && \
    ln -s nginx-${NGINX_PURE_VERSION} nginx-src && \
    git clone --depth 1 https://github.com/tokers/zstd-nginx-module.git && \
    git clone --depth 1 --recursive https://github.com/google/ngx_brotli.git && \
    git clone --depth 1 https://github.com/owasp-modsecurity/ModSecurity-nginx.git && \
    cd nginx-src && \
    ./configure --with-compat \
    --add-dynamic-module=../zstd-nginx-module \
    --add-dynamic-module=../ngx_brotli \
    --add-dynamic-module=../ModSecurity-nginx && \
    make -j$(nproc) modules

# 4. 下载 OWASP 核心规则集 (CRS) 和默认配置
RUN mkdir -p /usr/src/modsec && \
    curl -fSsL https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/modsecurity.conf-recommended -o /usr/src/modsec/modsecurity.conf && \
    curl -fSsL https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/unicode.mapping -o /usr/src/modsec/unicode.mapping && \
    git clone --depth 1 https://github.com/coreruleset/coreruleset.git /usr/src/modsec/owasp-crs && \
    cp /usr/src/modsec/owasp-crs/crs-setup.conf.example /usr/src/modsec/owasp-crs/crs-setup.conf

# 最终运行时镜像
FROM nginx:${NGINX_VERSION}

LABEL maintainer="seaside <seaside@qq.com>"

ARG NGINX_VERSION

# 安装运行时必需的共享库 (包含 ModSecurity 所需)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    libzstd1 libbrotli1 \
    libxml2 libxslt1.1 libgeoip1 libgd3 liblmdb0 libcurl4 liblua5.3-0 && \
    rm -rf /var/lib/apt/lists/*

# 从构建机复制 ModSecurity 核心库、模块和规则集
COPY --from=builder /usr/local/modsecurity /usr/local/modsecurity
COPY --from=builder /usr/local/lib/libmodsecurity.so* /usr/local/lib/
COPY --from=builder /usr/src/nginx-src/objs/ngx_http_zstd_*.so /usr/lib/nginx/modules/
COPY --from=builder /usr/src/nginx-src/objs/ngx_http_brotli_*.so /usr/lib/nginx/modules/
COPY --from=builder /usr/src/nginx-src/objs/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/

# 刷新动态链接库
RUN ldconfig

# 复制 WAF 配置和 CRS 规则集
COPY --from=builder /usr/src/modsec /etc/nginx/modsec

STOPSIGNAL SIGQUIT

# 提示：需在 nginx.conf 顶部加载
# load_module modules/ngx_http_zstd_filter_module.so;
# load_module modules/ngx_http_brotli_filter_module.so;
# load_module modules/ngx_http_modsecurity_module.so;