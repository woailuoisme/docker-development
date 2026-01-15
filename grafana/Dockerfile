FROM grafana/grafana:main

ARG CHANGE_SOURCE=false
ARG TIMEZONE=Asia/Shanghai
USER root
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories; \
    fi && \
    apk add --no-cache tzdata && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone

RUN grafana-cli plugins install grafana-clock-panel && \
    grafana-cli plugins install grafana-simple-json-datasource

COPY grafana.ini /etc/grafana/grafana.ini
COPY datasources /etc/grafana/provisioning/datasources
COPY dashboards /etc/grafana/provisioning/dashboards
COPY provisioning/alerting /etc/grafana/provisioning/alerting

# 设置权限（使用 UID:GID 472:0，Grafana 官方镜像的默认用户）
RUN chown -R 472:0 /etc/grafana/provisioning && \
    chmod -R 755 /etc/grafana/provisioning

# 切换回 grafana 用户（UID 472）
USER 472

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=10s --timeout=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# 使用默认的 Grafana 入口点
