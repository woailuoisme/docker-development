ARG GRAFANA_VERSION=13.0-slim
FROM grafana/grafana:${GRAFANA_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

# ==============================================================================
# SECTION 1: 构建参数与系统环境配置
# ==============================================================================
ARG TIMEZONE=Asia/Shanghai
USER root

# 适配基础包、系统时区与 grafana-cli 兼容脚本
RUN if [ -f /etc/alpine-release ]; then \
        apk add --no-cache curl tzdata; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            curl \
            tzdata && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    fi && \
    ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    if ! command -v grafana-cli >/dev/null 2>&1 && command -v grafana >/dev/null 2>&1; then \
        printf '#!/bin/sh\nexec grafana cli "$@"\n' > /usr/local/bin/grafana-cli && \
        chmod +x /usr/local/bin/grafana-cli; \
    fi

# ==============================================================================
# SECTION 2: 官方与社区插件批量安装 (按职能分组合并)
# ==============================================================================
# 1. 数据源增强:
#    - yesoreyeram-infinity-datasource: 万能数据源，支持 HTTP/REST, JSON, CSV, GraphQL 等接入
#    - victoriametrics-datasource: VictoriaMetrics 官方指标数据源插件 (支持原生 MetricsQL 语法补全与高级特性)
#    - victoriametrics-logs-datasource: VictoriaLogs 官方日志检索与聚合数据源插件（强依赖）
# 2. 高级可视化与大屏图表:
#    - volkovlabs-echarts-panel: Apache ECharts 渲染面板，支持桑基图、雷达图、关系拓扑及高级定制
#    - marcusolsson-hourly-heatmap-panel: 24小时 x 7天 GitHub 风格业务与故障时段热力矩阵
# 3. 动态内容与排版:
#    - marcusolsson-dynamictext-panel: 支持 Markdown/HTML/Handlebars 动态模板渲染卡片
RUN for plugin in \
        yesoreyeram-infinity-datasource \
        victoriametrics-datasource \
        victoriametrics-logs-datasource \
        volkovlabs-echarts-panel \
        marcusolsson-hourly-heatmap-panel \
        marcusolsson-dynamictext-panel \
    ; do \
        grafana-cli plugins install "$plugin"; \
    done && \
    chown -R 472:0 /var/lib/grafana && \
    chmod -R 755 /var/lib/grafana && \
    rm -rf /tmp/* /var/tmp/*

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

RUN chmod -R 755 /etc/grafana

# ==============================================================================
# SECTION 5: 运行时环境与安全规范
# ==============================================================================
# 切换回官方默认的 grafana 用户 (UID 472)
USER 472

EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD ["sh", "-c", "curl -f http://localhost:3000/api/health || exit 1"]

