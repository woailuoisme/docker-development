# 统一可观测性技术栈 (Observability Stack)

本项目将现代云原生全栈可观测性能力（Metrics、Logs、Traces）深度整合于 `observability/` 统一模块下，坚持**高性能、低内存、低存储成本**的最佳工程实践。

时序指标全面采用 **VictoriaMetrics** 原生单核抓取与存储，日志引擎采用轻量 **VictoriaLogs**，数据流中继采用 Rust 编写的 **Vector**，可视化由 **Grafana** 统一接入。

---

## 一、组件构成与职责划分

当前 `observability/` 目录下实际包含的容器服务矩阵如下：

### 1. 核心平台与数据管道

| 服务名 | 容器名 | 所属子目录 | 内部地址 | 宿主机端口 | 职责说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **grafana** | `grafana` | `grafana/` | `http://grafana:3000` | `${GRAFANA_PORT:-13000}` | 统一可视化看板，预置 VictoriaMetrics / VictoriaLogs 数据源 |
| **vector** | `vector` | `vector/` | `http://vector:8686` | `${VECTOR_PORT:-8686}` | Rust 高性能 Docker 容器日志采集、清洗并推送到 VictoriaLogs |
| **victoria-metrics** | `victoria-metrics` | `victoria/victoria-metrics/` | `http://victoria-metrics:8428` | `${VICTORIA_METRICS_PORT:-8428}` | TSDB 核心引擎，内置 Prometheus 抓取器与 `vmui` 指标看板 |
| **victoria-logs** | `victoria-logs` | `victoria/victoria-logs/` | `http://victoria-logs:9428` | `${VICTORIA_LOGS_PORT:-9428}` | 极速轻量日志存储库，内置 `vmui` 日志看板，支持 LogsQL |
| **tempo** | `tempo` | `tempo/` | `http://tempo:3200` | `${TEMPO_PORT:-3200}` | (备选) 链路追踪存储后端，支持 OTLP 写入与 TraceQL 查询 |

### 2. 监控探针集群 (位于 `victoria/` 模块下)

| 服务名 | 容器名 | 所属子目录 | 内部端口 | 抓取路径 | 探针监控目标 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **node-exporter** | `node-exporter` | `victoria/node-exporter/` | `9100` | `/metrics` | 宿主机 CPU、内存、磁盘与网络核心 OS 指标 |
| **cadvisor** | `cadvisor` | `victoria/cadvisor/` | `8080` | `/metrics` | 容器资源占用精简指标 (`--docker_only=true`) |
| **valkey-exporter** | `valkey-exporter` | `victoria/valkey-exporter/` | `9121` | `/metrics` | Valkey / Redis 缓存命中率与内存状态 |
| **postgres-exporter** | `postgres-exporter` | `victoria/postgres-exporter/` | `9187` | `/metrics` | PostgreSQL 数据库连接数、事务与锁状态 |

---

## 二、架构与数据流拓扑

```text
       ┌────────────────────────┐
       │   宿主机所有 Docker 容器│
       └───────────┬────────────┘
                   │
  ┌────────────────┼─────────────────────┐
  │ Docker 日志流  │ 探针采集 / 暴露     │ OTLP Traces (可选)
  ▼                ▼                     ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│    vector    │ │4大 Exporters │ │    tempo     │
│ (端口: 8686) │ │ (node/cad等) │ │ (端口: 3200) │
└──────┬───────┘ └──────┬───────┘ └──────▲───────┘
       │                ▲                │
       ├────────────┐   │ 内置拉取抓取   │
       │ HTTP Push  │   │ (promscrape)   │
       ▼            ▼   │                │
┌──────────────┐ ┌──────┴─────────┐      │
│victoria-logs │ │victoria-metrics│      │
│ (端口: 9428) │ │ (端口: 8428)   │      │
└──────┬───────┘ └──────┬─────────┘      │
       │                │                │
       │ LogsQL         │ PromQL         │ TraceQL
       ▼                ▼                │
┌─────────────────────────────────────┐  │
│               grafana               ├──┘
│            (端口: 13000)            │
└─────────────────────────────────────┘
```

---

## 三、真实目录结构

```text
observability/
├── docker-compose.yml               # 统一可观测性顶级入口编排 (include)
├── README.md                        # 本技术栈文档
├── vector/                          # Vector 数据管道 (基于 Rust)
│   ├── docker-compose.yml
│   └── vector.yaml                  # 容器日志采集与 VictoriaLogs 推送流水线
├── victoria/                        # Victoria 极速高压缩监控与日志套件
│   ├── docker-compose.yml           # 子模块顶层编排 (include)
│   ├── victoria-metrics/            # VictoriaMetrics TSDB 核心与原生抓取
│   │   ├── docker-compose.yml
│   │   └── prometheus.yml           # 原生抓取规则配置 (自监控与探针配置)
│   ├── victoria-logs/               # VictoriaLogs 极速轻量日志引擎
│   │   └── docker-compose.yml
│   ├── node-exporter/               # 宿主机硬件资源指标探针
│   │   └── docker-compose.yml
│   ├── cadvisor/                    # 容器资源指标精简探针
│   │   └── docker-compose.yml
│   ├── valkey-exporter/             # Valkey/Redis 缓存监控探针
│   │   └── docker-compose.yml
│   └── postgres-exporter/           # PostgreSQL 数据库监控探针
│       └── docker-compose.yml
├── tempo/                           # Tempo 链路追踪存储后端 (备选)
│   ├── docker-compose.yml
│   └── tempo.yaml                   # 追踪存储与压缩规则
└── grafana/                         # Grafana 统一可视化控制台
    ├── docker-compose.yml
    ├── Dockerfile                   # 定制包含官方 VictoriaLogs 插件
    ├── grafana.ini                  # Grafana 基础参数配置
    ├── dashboards/                  # 预置开箱即用仪表盘
    │   ├── docker_logs_dashboard.json
    │   └── iot_vending_dashboard.json
    └── provisioning/                # 数据源与告警自动预置
        ├── alerting/                # 告警规则与通知策略
        │   ├── alert-rules.yml
        │   ├── contact-points.yml
        │   └── notification-policies.yml
        ├── dashboards/              # 仪表盘加载规则
        │   └── dashboards.yaml
        └── datasources/             # 数据源预置 (VictoriaMetrics/VictoriaLogs/Tempo/IoT)
            ├── tcdb_vending_ds.yaml
            ├── tempo_ds.yaml
            ├── victoria_ds.yaml
            └── victorialogs_ds.yaml
```

---

## 四、启动与使用指南

### 1. 启动常用组合

在根目录下按需执行：

```bash
# 启动 Grafana 看板、Vector 管道与 Victoria 全家桶 (指标库 + 日志库 + 4 大探针)
docker compose up -d grafana vector victoria-metrics victoria-logs node-exporter cadvisor valkey-exporter postgres-exporter

# 若需同时启用链路追踪 (Tempo)
docker compose up -d grafana vector victoria-metrics victoria-logs node-exporter cadvisor valkey-exporter postgres-exporter tempo
```

### 2. 服务访问入口

- **Grafana 综合看板**：`http://localhost:13000`（默认账密：`admin` / `Admin123!`，或反代域名 `https://grafana.{$SITE_ADDRESS}`）
- **VictoriaMetrics 指标控制台 (`vmui`)**：`http://localhost:8428/vmui`（或反代域名 `https://prom.{$SITE_ADDRESS}`）
- **VictoriaLogs 日志控制台 (`vmui`)**：`http://localhost:9428/select/vmui/`（或反代域名 `https://logs.{$SITE_ADDRESS}`）
- **Vector 内部运行指标**：`http://localhost:8686/metrics`
- **Tempo 探活就绪检查**：`curl http://localhost:3200/ready`
