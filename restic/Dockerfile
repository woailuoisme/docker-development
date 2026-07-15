ARG ALPINE_VERSION=3.24
ARG SUPERCRONIC_VERSION=0.2.46

FROM alpine:${ALPINE_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

ARG SUPERCRONIC_VERSION

RUN apk add --no-cache restic tzdata openssh-client ca-certificates bash curl \
    && ARCH=$(uname -m) \
    && case "$ARCH" in \
         x86_64)  GOARCH="amd64" ;; \
         aarch64) GOARCH="arm64" ;; \
         armv7l)  GOARCH="arm"   ;; \
         *)       echo "Unsupported arch: $ARCH" && exit 1 ;; \
       esac \
    && curl -fsSL \
         "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-${GOARCH}" \
         -o /usr/local/bin/supercronic \
    && chmod +x /usr/local/bin/supercronic \
    && mkdir -p /data /repo /scripts

COPY --chmod=755 scripts/entrypoint.sh /entrypoint.sh
COPY --chmod=755 scripts/backup.sh     /scripts/backup.sh

ENV TZ=Asia/Shanghai \
    RESTIC_REPOSITORY=/repo \
    BACKUP_SOURCE=/data \
    RESTIC_KEEP_DAILY=7 \
    RESTIC_KEEP_WEEKLY=4 \
    RESTIC_KEEP_MONTHLY=6 \
    CRON_SCHEDULE="0 2 * * *"

HEALTHCHECK --interval=60s --timeout=10s --retries=3 --start-period=15s \
    CMD restic version > /dev/null 2>&1 || exit 1

VOLUME ["/data", "/repo"]
ENTRYPOINT ["/entrypoint.sh"]
