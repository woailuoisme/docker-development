ARG GRAFANA_VERSION=13.0-slim
FROM grafana/grafana:${GRAFANA_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

# ==============================================================================
# SECTION 1: 构建参数与系统环境配置 (Debian Slim 换源与基础工具)
# ==============================================================================
ARG CHINA=true
ARG TIMEZONE=Asia/Shanghai
USER root

# 适配 Debian 12 (Bookworm) / Debian 13 (Trixie) 源配置并安装基础工具
RUN if [ "${CHINA}" = "true" ]; then \
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
            sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources; \
        fi; \
        if [ -f /etc/apt/sources.list ]; then \
            sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
            sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
        fi; \
    fi && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        tzdata && \
    ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ==============================================================================
# SECTION 2: 官方与社区插件批量安装 (按监控职能分组合并)
# ==============================================================================
# 1. 数据源增强:
#    - yesoreyeram-infinity-datasource: 支持 HTTP/REST, CSV, JSON, GraphQL, XML 等泛数据源接入
#    - victoriametrics-logs-datasource: VictoriaLogs 官方日志检索与聚合数据源插件
# 2. 状态与指标聚合:
#    - grafana-polystat-panel: 类似蜂窝/多边形状态聚合，适合海量节点与设备统一概览
# 3. 内容与富文本:
#    - marcusolsson-dynamictext-panel: 支持 Markdown/HTML/动态模版渲染富文本
# 4. 交互控制与操作:
#    - volkovlabs-form-panel: 业务表单操作，在面板直接向后台发送 API/控制指令
# 5. 看板与大屏辅助:
#    - grafana-clock-panel: 监控大屏显眼时间与时钟展示
RUN for plugin in \
        yesoreyeram-infinity-datasource \
        victoriametrics-logs-datasource \
        grafana-polystat-panel \
        marcusolsson-dynamictext-panel \
        volkovlabs-form-panel \
        grafana-clock-panel \
    ; do \
        grafana-cli plugins install "$plugin"; \
    done

# ==============================================================================
# SECTION 3: UI 界面与白标定制 (静态清理与定制)
# ==============================================================================
# 1. 标题与控制台文字替换
# 2. 移除 Footer 文档、支持、社区等外部链接
RUN if [ -d /usr/share/grafana/public/build ]; then \
        find /usr/share/grafana/public/build/ -name "*.js" -exec sed -i 's/Welcome to Grafana/欢迎使用控制台/g' {} +; \
    fi && \
    if [ -f /usr/share/grafana/public/views/index.html ]; then \
        sed -i 's|<\/head>|<style>footer { display: none !important; }</style><\/head>|g' /usr/share/grafana/public/views/index.html; \
    fi

# ==============================================================================
# SECTION 4: 配置文件初始化与权限设定 (使用 --chown 减少构建层)
# ==============================================================================
COPY --chown=472:0 grafana.ini /etc/grafana/grafana.ini
COPY --chown=472:0 provisioning/ /etc/grafana/provisioning/
COPY --chown=472:0 dashboards/ /etc/grafana/provisioning/dashboards/

RUN chmod -R 755 /etc/grafana /var/lib/grafana

# ==============================================================================
# SECTION 5: 运行时环境与安全规范
# ==============================================================================
# 切换回官方默认的 grafana 用户 (UID 472)
USER 472

EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD ["sh", "-c", "curl -f http://localhost:3000/api/health || exit 1"]

