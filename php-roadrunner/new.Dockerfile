
# Docker 会自动填充这些变量，但必须先用 ARG 声明
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETOS

RUN echo "我正在为 $TARGETPLATFORM 构建"
RUN echo "核心架构是 $TARGETARCH"

# 示例：根据架构安装不同的工具
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        echo "检测到 ARM64，执行特定优化..."; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
        echo "检测到 AMD64，执行标准构建..."; \
    fi
FROM ghcr.io/roadrunner-server/roadrunner:2025.1.6 AS roadrunner
FROM jiaoio/php-base-cli
COPY --from=roadrunner /usr/bin/rr /usr/local/bin/rr

RUN chmod +x /usr/local/bin/rr