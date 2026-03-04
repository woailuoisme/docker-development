ARG GARAGE_VERSION=v2.2.0
FROM dxflrs/garage:${GARAGE_VERSION} AS garage

FROM alpine:3.23

COPY --from=garage /garage /garage
COPY --chmod=755 init.sh /init.sh
COPY garage.toml /etc/garage.toml

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=20s \
  CMD /garage status >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/init.sh"]
