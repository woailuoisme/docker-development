ARG OPENBAO_VERSION=2.6
FROM openbao/openbao:${OPENBAO_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

COPY --chown=100:1000 config/openbao.hcl /openbao/config/openbao.hcl

HEALTHCHECK --interval=15s --timeout=5s --start-period=15s --retries=3 \
    CMD ["wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:8200/v1/sys/health?uninitcode=200&sealedcode=200"]

EXPOSE 8200
