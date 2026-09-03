ARG CADDY_BASE_VERSION=2.11.4
FROM jiaoio/caddy-base:${CADDY_BASE_VERSION}
#FROM ccr.ccs.tencentyun.com/jiaoio/caddy-base:latest

COPY sites /etc/caddy/sites
COPY snippets /etc/caddy/snippets
COPY templates /etc/caddy/templates
COPY Caddyfile /etc/caddy/Caddyfile
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

CMD ["/usr/local/bin/startup.sh"]

HEALTHCHECK --interval=60s --timeout=3s --start-period=5s --retries=3 \
    CMD ["wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/health"]
