FROM alpine:latest

RUN apk add --no-cache dnsmasq drill

COPY dnsmasq.conf /etc/dnsmasq.conf

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD nslookup localhost 127.0.0.1 || exit 1

EXPOSE 53/udp 53/tcp

ENTRYPOINT ["dnsmasq", "-k", "--log-facility=-"]
CMD ["-C", "/etc/dnsmasq.conf"]
