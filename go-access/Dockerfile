ARG GOACCESS_VERSION=latest
FROM allinurl/goaccess:${GOACCESS_VERSION}

ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    GOACCESS_LOG="/srv/logs/access.log" \
    GOACCESS_CONFIG="/etc/goaccess/goaccess.conf" \
    GOACCESS_WS_URL="ws://127.0.0.1:7890" \
    GOACCESS_OUTPUT="/srv/logs/report.html"

# 打包配置
COPY goaccess.conf /etc/goaccess/goaccess.conf

# 重置入口并使用 Shell 形式启动，确保 ENV 变量和配置文件被读取
ENTRYPOINT []
CMD goaccess ${GOACCESS_LOG} \
    --config-file=${GOACCESS_CONFIG} \
    --num-test=0 \
    --real-time-html \
    --ws-url=${GOACCESS_WS_URL} \
    --addr=0.0.0.0 \
    --port=7890 \
    --output=${GOACCESS_OUTPUT}

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=15s \
    CMD pgrep goaccess || exit 1