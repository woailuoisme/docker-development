FROM jiaoio/caddy-base:latest
#FROM ccr.ccs.tencentyun.com/jiaoio/caddy-base:latest

COPY sites /etc/caddy/sites
COPY snippets /etc/caddy/snippets
COPY templates /etc/caddy/templates
COPY startup.sh /usr/local/bin/startup.sh
COPY Caddyfile /etc/caddy/Caddyfile
RUN chmod +x /usr/local/bin/startup.sh
#ENV GOMAXPROCS=2

CMD ["/usr/local/bin/startup.sh"]

HEALTHCHECK --interval=60s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8888/health || exit 1

