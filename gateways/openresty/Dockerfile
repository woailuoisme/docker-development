ARG RESTY_VERSION="1.27.1.2"
ARG RESTY_IMAGE_BASE="bookworm"

# --- 第一阶段：构建阶段 (Builder) ---
FROM openresty/openresty:${RESTY_VERSION}-${RESTY_IMAGE_BASE}-buildpack AS builder

# 使用 --tree 参数安装到指定目录，方便整体拷贝
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-auto-ssl --tree /usr/local/openresty/luarocks

# --- 第二阶段：运行阶段 (Runtime) ---
FROM openresty/openresty:${RESTY_VERSION}-${RESTY_IMAGE_BASE}-fat

LABEL maintainer="admin@haoxiaoguai.xyz"

# 只安装运行所需的最小依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    bash \
    tzdata \
    openssl \
    socat \
    && rm -rf /var/lib/apt/lists/*

# 从构建阶段拷贝已安装的 lua 模块
# luarocks 默认安装路径通常在 /usr/local/openresty/luajit/share/lua/5.1/ 和 /usr/local/openresty/luajit/lib/lua/5.1/
COPY --from=builder /usr/local/openresty/luajit/share/lua/5.1/ /usr/local/openresty/luajit/share/lua/5.1/
COPY --from=builder /usr/local/openresty/luajit/lib/lua/5.1/ /usr/local/openresty/luajit/lib/lua/5.1/
# 拷贝 auto-ssl 的可执行辅助脚本 (如果有)
COPY --from=builder /usr/local/openresty/luajit/bin/resty-auto-ssl /usr/local/openresty/luajit/bin/

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建必要的目录并设置权限
RUN mkdir -p /var/log/nginx /var/cache/nginx /usr/local/openresty/nginx/conf/conf.d \
    /etc/resty-auto-ssl \
    && chown -R www-data:www-data /var/log/nginx /var/cache/nginx /usr/local/openresty/nginx/ \
    /etc/resty-auto-ssl

# 拷贝配置文件备份
COPY nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

EXPOSE 80 443 443/udp

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
