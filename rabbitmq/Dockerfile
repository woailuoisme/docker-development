ARG RABBITMQ_VERSION=4.2-management-alpine
FROM rabbitmq:${RABBITMQ_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

ARG VERSION=4.2.0
RUN set -eux; \
    apk add --no-cache curl; \
    curl -fL -o /opt/rabbitmq/plugins/rabbitmq_delayed_message_exchange-4.2.0.ez \
    https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v4.2.0/rabbitmq_delayed_message_exchange-4.2.0.ez && \
    rabbitmq-plugins enable rabbitmq_delayed_message_exchange

COPY config/rabbitmq.conf /etc/rabbitmq/

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD rabbitmq-diagnostics -q ping