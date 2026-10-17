# Gatus (自动化服务健康检查与状态页看板)

本项目基于开源的自动化服务健康监控与现代化状态页看板 [Gatus](https://github.com/TwiN/gatus)（Go 语言开发），为开发与生产环境提供轻量、高颜值、易维护的容器服务运行状态监控与对外展示看板。

---

## 🌟 核心特性与优势

- **极轻量原生架构**：使用 Go 语言编写，打包为静态二进制文件（scratch 基础镜像），内存占用通常在 20MB 以内，无多余依赖与开销。
- **高颜值状态页看板**：原生自带现代化响应式 Web UI，直观展现所有服务的正常运行率（Uptime）、响应延迟趋势图及异常历史。
- **多协议探针支持**：
  - **HTTP / HTTPS**：支持响应状态码、响应体匹配、延迟阈值（`[RESPONSE_TIME] < 300`）、TLS 证书过期天数检查。
  - **TCP**：支持数据库、消息队列等端口连通性探测（`[CONNECTED] == true`）。
  - **DNS**：支持测试指定 DNS 节点的解析响应状态（`[DNS_RCODE] == NOERROR`）。
  - **ICMP Ping**：支持网络层丢包率与往返时延探测。
- **持久化与历史回放**：默认采用嵌入式 **SQLite** 本地单文件持久化，历史健康状态与时间线一目了然，重启无状态丢失。
- **云原生可观测性整合**：原生暴露 `/metrics` 接口（Prometheus 格式指标），可轻松接入 VictoriaMetrics / Grafana 生态。
- **全方位告警集成**：支持 Slack、Discord、Telegram、PagerDuty、Gotify、Webhook 及 Email 等十余种告警媒介。

---

## 🏗️ 端口与持久化规范

### 1. 服务端口

| 协议 / 服务 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **HTTP Web / API / Metrics** | `8080` | `9081:8080` | 状态页 Web 仪表板、健康接口与 `/metrics` 指标端点 |

### 2. 持久化数据与配置路径

持久化路径遵循项目统一规范：

| 宿主机路径 | 容器内挂载路径 | 权限 / 说明 |
| :--- | :--- | :--- |
| `./config` | `/config` | Gatus 核心配置文件目录（含 `config.yaml`） |
| `${DATA_PATH}gatus` | `/data` | SQLite 数据库文件持久化（`data.db`） |

---

## ⚙️ 配置文件说明 (`config/config.yaml`)

Gatus 通过挂载的 `./config/config.yaml` 进行端点管理，预置了当前开发环境核心服务探测示例：

```yaml
web:
  port: 8080

ui:
  title: "服务状态监控 | DevOps Development"
  description: "DevOps 本地容器化微服务实时健康监控与状态看板"
  header: "DevOps 基础设施状态看板"
  default-sort: "group"

storage:
  type: sqlite
  path: /data/data.db

metrics: true

endpoints:
  - name: Caddy Gateway
    group: Gateways
    url: "http://caddy:2019/metrics"
    interval: 30s
    conditions:
      - "[STATUS] == 200"

  - name: VictoriaMetrics
    group: Observability
    url: "http://victoria-metrics:8428/health"
    interval: 30s
    conditions:
      - "[STATUS] == 200"

  - name: PostgreSQL
    group: Databases
    url: "tcp://postgres:5432"
    interval: 30s
    conditions:
      - "[CONNECTED] == true"

  - name: Valkey Cache
    group: Databases
    url: "tcp://valkey:6379"
    interval: 30s
    conditions:
      - "[CONNECTED] == true"
```

---

## 🚀 快速启动

### 1. 启用模块编排

在 `observability/docker-compose.yml` 中取消对 Gatus 的注释：

```yaml
include:
  # ...
  - gatus/docker-compose.yml # Gatus 自动化服务健康检查与状态页看板
```

### 2. 启动服务

```bash
docker compose up -d gatus
```

访问 `http://localhost:9081` 即可查看服务状态看板。

---

## 🌐 Caddy 反向代理接入

如需通过子域名接入（例如 `status.{$SITE_ADDRESS}`），可在 `gateways/caddy/Caddyfile` 中启用：

```caddyfile
# 公开状态页（无需登录）
import proxy-app status.{$SITE_ADDRESS} gatus:8080

# 或启用身份认证拦截（通过 Authelia 保护）
# import proxy-app-auth status.{$SITE_ADDRESS} gatus:8080
```

---

## 📊 Prometheus / VictoriaMetrics 指标采集

Gatus 已启用 `metrics: true`，会在 `http://gatus:8080/metrics` 暴露标准指标。如需让 `vmagent` 抓取 Gatus 自身指标，可在 `observability/victoria-agent/prometheus.yml` 中追加抓取目标：

```yaml
  - job_name: "gatus"
    scrape_interval: 30s
    metrics_path: /metrics
    static_configs:
      - targets: ["gatus:8080"]
        labels:
          environment: "development"
          service: "gatus"
```
