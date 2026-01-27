FROM grafana/grafana:12.3-ubuntu

ARG CHANGE_SOURCE=true
ARG TIMEZONE=Asia/Shanghai
USER root
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/' /etc/apt/sources.list; \
    fi && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#infinity解决“非数据库”来源的数据展示问题。
#PolyStat解决设备太多、看不过来的问题。
#Dynamic Text解决图表太死板、无法显示富文本的问题。
#Business Forms解决只能监控、不能操作设备的问题。
#Clock解决监控大屏没有显眼时间的问题。
RUN grafana-cli plugins install yesoreyeram-infinity-datasource && \
    grafana-cli plugins install marcusolsson-dynamictext-panel && \
    grafana-cli plugins install grafana-polystat-panel && \
    grafana-cli plugins install volkovlabs-form-panel && \
    grafana-cli plugins install grafana-clock-panel

COPY grafana.ini /etc/grafana/grafana.ini
COPY provisioning /etc/grafana/provisioning
COPY dashboards /etc/grafana/provisioning/dashboards

# 统一设置权限
# /etc/grafana 为配置文件目录，/var/lib/grafana 为数据目录
RUN chown -R 472:0 /etc/grafana /var/lib/grafana && \
    chmod -R 755 /etc/grafana /var/lib/grafana

# 切换回官方默认的 grafana 用户
USER 472

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# 使用默认的 Grafana 入口点
