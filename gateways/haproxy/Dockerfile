FROM haproxy:3.4-alpine

LABEL maintainer="seaside <531773730@qq.com>"

ENV TZ=Asia/Shanghai

USER root

RUN apk add --no-cache bash curl openssl socat tzdata && \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    mkdir -p /var/lib/haproxy /etc/haproxy/certs && \
    chown -R haproxy:haproxy /var/lib/haproxy /etc/haproxy/certs

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    ln -snf /usr/local/bin/entrypoint.sh /usr/local/bin/haproxy-check && \
    ln -snf /usr/local/bin/entrypoint.sh /usr/local/bin/haproxy-reload && \
    ln -snf /usr/local/bin/entrypoint.sh /usr/local/bin/haproxy-cli
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY conf.d/ /usr/local/etc/haproxy/conf.d/
COPY maps/ /usr/local/etc/haproxy/maps/

HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
    CMD ["sh", "-c", "curl -f http://127.0.0.1:80/healthz || exit 1"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["haproxy", "-W", "-db", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
