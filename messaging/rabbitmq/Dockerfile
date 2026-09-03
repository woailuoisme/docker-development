ARG RABBITMQ_VERSION=4.3.2-management-alpine
FROM rabbitmq:${RABBITMQ_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

COPY config/rabbitmq.conf /etc/rabbitmq/

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ["sh", "-c", "rabbitmq-diagnostics -q ping"]
