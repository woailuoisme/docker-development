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
| **victoria-metrics** | `victoria-metrics` | `victoria-metrics/` | `http://victoria-metrics:8428` | `${VICTORIA_METRICS_PORT:-8428}` | TSDB 核心引擎，内置 Prometheus 抓取器与 `vmui` 指标看板 |
| **victoria-logs** | `victoria-logs` | `victoria-logs/` | `http://victoria-logs:9428` | `${VICTORIA_LOGS_PORT:-9428}` | 极速轻量日志存储库，内置 `vmui` 日志看板，支持 LogsQL |
| **tempo** | `tempo` | `tempo/` | `http://tempo:3200` | `${TEMPO_PORT:-3200}` | (备选) 链路追踪存储后端，支持 OTLP 写入与 TraceQL 查询 |
| **vmagent** | `vmagent` | `victoria-agent/` | `http://vmagent:8429` | `${VMAGENT_PORT:-8429}` | 专职指标抓取代理与缓冲中继，支持无丢包重试与过滤聚合 |
| **vmalert** | `vmalert` | `victoria-alert/` | `http://vmalert:8880` | `${VMALERT_PORT:-8880}` | 规则评估与报警触发服务，支持 MetricsQL 计算与状态写回 |
| **vmbackup** | `vmbackup` | `victoria-backup/` | - | - | 零停机瞬时一致性快照与增量备份工具 (定时守护运行) |

### 2. 监控探针集群 (位于 `exporters/` 模块下)

| 服务名 | 容器名 | 所属子目录 | 内部端口 | 抓取路径 | 探针监控目标 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **node-exporter** | `node-exporter` | `exporters/node-exporter/` | `9100` | `/metrics` | 宿主机 CPU、内存、磁盘与网络核心 OS 指标 |
| **cadvisor** | `cadvisor` | `exporters/cadvisor/` | `8080` | `/metrics` | 容器资源占用精简指标 (`--docker_only=true`) |
| **valkey-exporter** | `valkey-exporter` | `exporters/valkey-exporter/` | `9121` | `/metrics` | Valkey / Redis 缓存命中率与内存状态 |
| **postgres-exporter** | `postgres-exporter` | `exporters/postgres-exporter/` | `9187` | `/metrics` | PostgreSQL 数据库连接数、事务与锁状态 |

---

## 二、架构与数据流拓扑

```text
       ┌────────────────────────┐
       │   宿主机所有 Docker 容器│
       └───────────┬────────────┘
                   │
  ┌────────────────┼─────────────────────┐
  │ Docker 日志流  │ 探针暴露            │ OTLP Traces (可选)
  ▼                ▼                     ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│    vector    │ │4大 Exporters │ │    tempo     │
│ (端口: 8686) │ │ (node/cad等) │ │ (端口: 3200) │
└──────┬───────┘ └──────┬───────┘ └──────▲───────┘
       │                ▲                │
       │ HTTP Push      │ 统一抓取       │
       ▼                │                │
┌──────────────┐ ┌──────┴───────┐        │
│victoria-logs │ │   vmagent    │        │
│ (端口: 9428) │ │ (端口: 8429) │        │
└──────┬───────┘ └──────┬───────┘        │
       │                │ remoteWrite    │
       │                ▼                │
       │         ┌──────────────┐        │
       │         │victoria-metrics───────┼───────┐
       │         │ (端口: 8428) │        │       │
       │         └──────┬───────┘        │       │ 快照读取
       │                ▲                │       ▼
       │         MetricsQL / 写回        │ ┌──────────┐
       │                │                │ │ vmbackup │
       │         ┌──────┴───────┐        │ └──────────┘
       │         │   vmalert    │        │
       │         │ (端口: 8880) │        │
       │         └──────┬───────┘        │
       │                │ 告警推送       │
       │                ▼                │
       │         ┌──────────────┐        │
       │         │ Alertmanager │        │
       │         └──────────────┘        │
       │                                 │
       │ LogsQL         PromQL           │ TraceQL
       ▼                ▼                │
┌────────────────────────────────────────┴┐
│                 grafana                 │
│              (端口: 13000)              │
└─────────────────────────────────────────┘
```

---

## 三、真实目录结构

```text
observability/
├── docker-compose.yml               # 统一可观测性顶级入口编排 (include)
├── README.md                        # 本技术栈文档
├── vector/                          # Vector 数据管道 (基于 Rust)
│   ├── docker-compose.yml
│   ├── vector.yaml                  # 容器日志采集与 VictoriaLogs 推送流水线
│   └── README.md
├── victoria-metrics/                # VictoriaMetrics TSDB 核心引擎
│   ├── docker-compose.yml
│   ├── prometheus.yml               # 原生抓取规则配置
│   └── README.md
├── victoria-logs/                   # VictoriaLogs 极速轻量日志引擎
│   ├── docker-compose.yml
│   └── README.md
├── victoria-agent/                  # vmagent 专职指标抓取代理与缓冲中继
│   ├── docker-compose.yml
│   ├── prometheus.yml               # 统一抓取目标与 remoteWrite 地址
│   └── README.md
├── victoria-alert/                  # vmalert 规则评估与报警触发服务
│   ├── docker-compose.yml
│   ├── alerts.yml                   # 基础预置告警规则 (基础设施/容器/TSDB)
│   └── README.md
├── victoria-backup/                 # vmbackup 零停机快照与增量备份工具
│   ├── docker-compose.yml           # 自动化定时增量备份守护进程
│   └── README.md
├── exporters/                       # 监控探针套件
│   ├── docker-compose.yml           # 探针聚合编排 (include)
│   ├── README.md
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
│   ├── tempo.yaml                   # 追踪存储与压缩规则
│   └── README.md
└── grafana/                         # Grafana 统一可视化控制台
    ├── docker-compose.yml
    ├── Dockerfile                   # 定制包含官方 VictoriaLogs 插件
    ├── grafana.ini                  # Grafana 基础参数配置
    ├── README.md
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
# 启动 Grafana 看板、Vector 管道与 Victoria 核心全家桶 (指标库 + 日志库 + 4 大探针)
docker compose up -d grafana vector victoria-metrics victoria-logs node-exporter cadvisor valkey-exporter postgres-exporter

# 启用 VictoriaMetrics 进阶生产套件 (抓取代理 vmagent + 告警计算 vmalert + 定时备份 vmbackup)
docker compose up -d vmagent vmalert vmbackup

# 若需同时启用分布式链路追踪 (Tempo)
docker compose up -d tempo
```

### 2. 服务访问入口

- **Grafana 综合看板**：`http://localhost:13000`（默认账密：`admin` / `Admin123!`，或反代域名 `https://grafana.{$SITE_ADDRESS}`）
- **VictoriaMetrics 指标控制台 (`vmui`)**：`http://localhost:8428/vmui`（或反代域名 `https://prom.{$SITE_ADDRESS}`）
- **VictoriaLogs 日志控制台 (`vmui`)**：`http://localhost:9428/select/vmui/`（或反代域名 `https://logs.{$SITE_ADDRESS}`）
- **vmagent 抓取与中继状态**：`http://localhost:8429/targets`（查看各 Target 健康状态）
- **vmalert 告警规则看板**：`http://localhost:8880/`（查看当前 firing / pending 状态及规则）
- **vmbackup 备份任务日志**：`docker compose logs -f vmbackup`
- **Vector 内部运行指标**：`http://localhost:8686/metrics`
- **Tempo 探活就绪检查**：`curl http://localhost:3200/ready`

---

## 五、告警体系设计与双引擎选型说明

本项目提供了灵活完备的告警实现路径，支持根据团队规模与业务场景选用：

### 1. 引擎对比与适用场景

| 维度 | Grafana Unified Alerting | vmalert (VictoriaMetrics 原生) |
| :--- | :--- | :--- |
| **计算引擎** | Grafana 内部后台服务 | 独立轻量 Go 进程 `vmalert` |
| **查询语法** | 支持跨数据源混合（PromQL + SQL + LogsQL） | 深度优化 MetricsQL / PromQL |
| **资源开销** | 依赖 Grafana 实例运行 | 极低（约 30MB 内存） |
| **管理界面** | 丰富的富文本 Web UI、可视化静默与规则编辑器 | 极简原生只读看板 |
| **通知渠道** | 内置 Alertmanager（支持钉钉、企业微信、邮件等） | 专职向 Alertmanager 或 Webhook 推送 |
| **典型定位** | 适合全栈团队、跨源监控看板（日志+时序+SQL）告警 | 适合大规模纯时序高频规则计算与工业级防丢抖动 |

### 2. 告警配置落地路径

- **Grafana 告警规则**：集中维护于 `observability/grafana/provisioning/alerting/`（`alert-rules.yml`、`contact-points.yml`、`notification-policies.yml`）。
- **vmalert 告警规则**：集中维护于 `observability/victoria-alert/alerts.yml`，修改后可通过 `curl -X POST http://localhost:8880/-/reload` 秒级热重载。
