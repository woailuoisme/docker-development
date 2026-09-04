FROM nginx:1.31-trixie

# 复制自定义 Nginx 主配置
COPY nginx.conf /etc/nginx/nginx.conf

# 复制通用安全与功能模块片段
COPY snippets/ /etc/nginx/snippets/

# 复制默认站点模板 (容器启动时由 20-envsubst-on-templates.sh 自动渲染)
COPY templates/ /etc/nginx/templates/

# 复制自签 SSL 证书初始化脚本 (启动时自动执行)
COPY entrypoint.d/05-init-ssl.sh /docker-entrypoint.d/05-init-ssl.sh
RUN chmod +x /docker-entrypoint.d/05-init-ssl.sh

EXPOSE 80 443 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["curl", "-f", "http://localhost/healthz"]
