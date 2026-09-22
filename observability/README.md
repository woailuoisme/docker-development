# 统一可观测性技术栈 (Observability Stack)

本项目将现代云原生全栈可观测性能力（Metrics、Logs、Traces）深度整合于 `observability/` 统一模块下，坚持**高性能、低内存、低存储成本**的最佳工程实践。

时序指标由 **vmagent** 统一抓取、**VictoriaMetrics** 单机存储（VM 自身不再抓取，避免同一目标被两个 scraper 双写），日志引擎采用轻量 **VictoriaLogs**，数据流中继采用 Rust 编写的 **Vector**，可视化由 **Grafana** 统一接入。

---

## 一、组件构成与职责划分

当前 `observability/` 目录下实际包含的容器服务矩阵如下：

### 1. 核心平台与数据管道

| 服务名 | 容器名 | 所属子目录 | 内部地址 | 宿主机端口 | 职责说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **grafana** | `grafana` | `grafana/` | `http://grafana:3000` | `${GRAFANA_PORT:-13000}` | 统一可视化看板，预置 VictoriaMetrics / VictoriaLogs 数据源 |
| **vector** | `vector` | `vector/` | `http://vector:8686` | `${VECTOR_PORT:-8686}` | Rust 高性能 Docker 容器日志采集、清洗并推送到 VictoriaLogs |
| **victoria-metrics** | `victoria-metrics` | `victoria-metrics/` | `http://victoria-metrics:8428` | `${VICTORIA_METRICS_PORT:-8428}` | TSDB 核心引擎，只存不抓（抓取统一由 vmagent 负责），内置 `vmui` 指标看板 |
| **victoria-logs** | `victoria-logs` | `victoria-logs/` | `http://victoria-logs:9428` | `${VICTORIA_LOGS_PORT:-9428}` | 极速轻量日志存储库，内置 `vmui` 日志看板，支持 LogsQL |
| **jaeger** | `jaeger` | `jaeger/` | `http://jaeger:16686` | `${JAEGER_UI_PORT:-16686}` | (按需启用) 官方 Jaeger v2 镜像：自带 badger 存储，OTLP 摄取 + UI/查询 API 一体化 |
| **vmagent** | `vmagent` | `victoria-agent/` | `http://vmagent:8429` | `${VMAGENT_PORT:-8429}` | 专职指标抓取代理与缓冲中继，支持无丢包重试与过滤聚合 |
| **vmalert** | `vmalert` | `victoria-alert/` | `http://vmalert:8880` | `${VMALERT_PORT:-8880}` | 规则评估与报警触发服务，支持 MetricsQL 计算与状态写回 |

> 链路侧：当前现役数据面仍是 **`victoria-traces`**（`traces.` 域名 / `:10428`，Grafana 的 Jaeger 数据源指向它）。
> `jaeger/` 已入库但**默认不启用**（编排、Caddy 路由、vmagent 抓取任务三处均为注释态），彻底启用步骤见
> `jaeger/README.md`。注意 Jaeger v2 是 OTel Collector 发行版，自带 badger 存储、UI 只查自己的库，
> 无法把 UI 指向 VictoriaTraces 的 HTTP 查询接口 —— 因此它属于「替换而非叠加」。
> 备份与恢复**不是常驻服务**：原先的 `victoria-backup/` 守护容器已移除，统一改由 `scripts/victoria.sh` 提供
> （`just vm-backup-now` 备份、`vm-backup-restore-test` 恢复演练、`vm-restore` 灾难恢复），详见第六节。

### 2. 监控探针集群 (位于 `exporters/` 模块下)

| 服务名 | 容器名 | 所属子目录 | 内部端口 | 抓取路径 | 探针监控目标 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **node-exporter** | `node-exporter` | `exporters/node-exporter/` | `9100` | `/metrics` | 宿主机 CPU、内存、磁盘与网络核心 OS 指标 |
| **cadvisor** | `cadvisor` | `exporters/cadvisor/` | `8080` | `/metrics` | 容器资源占用精简指标 (`--docker_only=true`) — 暂停启用，编排已注释 |
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
│    vector    │ │3大 Exporters │ │   jaeger     │
│ (端口: 8686) │ │ (node/pg等)  │ │(端口: 16686) │
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
       │         │victoria-metrics───────┼
       │         │ (端口: 8428) │        │
       │         └──────┬───────┘        │
       │                ▲                │
       │         MetricsQL / 写回        │
       │                │                │
       │         ┌──────┴───────┐        │
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

> 图中第三列为链路侧：现役是 `victoria-traces`（`:10428` / `traces.` 域名，Grafana 的 Jaeger 数据源指向它）；
> `jaeger` 画在同一位置但**默认未启用**，两者是替换关系而非叠加。

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
├── victoria-metrics/                # VictoriaMetrics TSDB 核心引擎 (只存不抓)
│   ├── docker-compose.yml
│   └── README.md
├── victoria-logs/                   # VictoriaLogs 极速轻量日志引擎
│   ├── docker-compose.yml
│   └── README.md
├── victoria-traces/                 # VictoriaTraces 链路库 (当前现役链路数据面)
│   └── docker-compose.yml
├── victoria-agent/                  # vmagent 专职指标抓取代理与缓冲中继
│   ├── docker-compose.yml
│   ├── prometheus.yml               # 统一抓取目标与 remoteWrite 地址
│   └── README.md
├── victoria-alert/                  # vmalert 规则评估与报警触发服务
│   ├── docker-compose.yml
│   ├── alerts.yml                   # 基础预置告警规则 (基础设施/容器/TSDB)
│   └── README.md
├── jaeger/                          # Jaeger v2 链路数据面 (按需启用，编排已注释)
│   ├── docker-compose.yml
│   ├── config.yaml                  # 官方 config-badger.yaml 的裁剪版 (OTLP + badger + UI)
│   └── README.md
├── exporters/                       # 监控探针套件
│   ├── docker-compose.yml           # 探针聚合编排 (include)
│   ├── README.md
│   ├── node-exporter/               # 宿主机硬件资源指标探针
│   │   └── docker-compose.yml
│   ├── cadvisor/                    # 容器资源指标精简探针 (暂停使用，编排已注释)
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
        └── datasources/             # 数据源预置 (VictoriaMetrics/VictoriaLogs/VictoriaTraces/IoT)
            ├── tcdb_vending_ds.yaml
            ├── victoria_ds.yaml
            ├── victorialogs_ds.yaml
            └── victoriatraces_ds.yaml
```

---

## 四、启动与使用指南

### 1. 启动常用组合

在根目录下按需执行：

```bash
# 启动 Grafana 看板、Vector 管道与 Victoria 核心全家桶 (指标库 + 日志库 + 3 大探针，cAdvisor 暂停启用)
docker compose up -d grafana vector victoria-metrics victoria-logs node-exporter valkey-exporter postgres-exporter

# 启用 VictoriaMetrics 进阶生产套件 (抓取代理 vmagent + 告警计算 vmalert)
docker compose up -d vmagent vmalert

# 可选：链路侧换用 Jaeger v2 (自带 badger 存储；默认不启用，需先取消三处注释，见 jaeger/README.md)
docker compose up -d jaeger
```

### 2. 服务访问入口

- **Grafana 综合看板**：`http://localhost:13000`（默认账密：`admin` / `Admin123!`，或反代域名 `https://grafana.{$SITE_ADDRESS}`）
- **VictoriaMetrics 指标控制台 (`vmui`)**：`http://localhost:8428/vmui`（或反代域名 `https://prom.{$SITE_ADDRESS}`）
- **VictoriaLogs 日志控制台 (`vmui`)**：`http://localhost:9428/select/vmui/`（或反代域名 `https://logs.{$SITE_ADDRESS}`）
- **vmagent 抓取与中继状态**：`http://localhost:8429/targets`（查看各 Target 健康状态）
- **vmalert 告警规则看板**：`http://localhost:8880/`（查看当前 firing / pending 状态及规则）
- **备份与恢复**：`just vm-backup-now` / `vm-backup-restore-test` / `vm-restore`（非常驻服务，详见第六节）
- **Vector 内部运行指标**：`http://localhost:8686/metrics`
- **VictoriaTraces 链路 vmui**：`http://localhost:10428/select/vmui`（或反代域名 `https://traces.{$SITE_ADDRESS}`）
- **Jaeger 链路 UI**：`http://localhost:16686`（或 `https://jaeger.{$SITE_ADDRESS}`）—— **需先启用 `jaeger/`**

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
- **vmalert 告警规则**：集中维护于 `observability/victoria-alert/alerts.yml`，修改后可通过 `curl -X POST http://localhost:8880/-/reload` 秒级热重载；改动后先跑 `just vm-alert-test`（`vmalert-tool` 单元测试）验证规则行为，再上线。

---

## 六、时序库备份与恢复 (scripts/victoria.sh)

备份与恢复**不常驻容器**：原先的 `victoria-backup/` 守护容器已移除 —— 它只是把同一条 `vmbackup` 命令包成 24 小时循环，而脚本已覆盖同样的逻辑，留着会造成两处配置各自演化。统一入口如下：

| 命令 | 作用 | 是否触碰生产数据 |
| :--- | :--- | :--- |
| `just vm-backup-now` | 申请瞬时快照并增量备份到 `${DATA_PATH}victoria-backup/latest` | 否（源目录只读挂载） |
| `just vm-backup-restore-test` | 恢复演练：恢复到隔离目录 → 临时实例验证 → 自动清理 | 否 |
| `just vm-restore` | 灾难恢复：停 VM → 旧数据改名留存 → 恢复 → 起 VM | **是**（需输入 `yes` 确认，可改名回滚） |

脚本本体：`scripts/victoria.sh`（`./scripts/victoria.sh help` 查看全部子命令）。

如需**自动定时备份**，用宿主机 cron 调用同一条命令即可，逻辑仍然只有一份：

```bash
# 每日 03:30 备份（crontab -e）
30 3 * * * cd /path/to/development && ./scripts/victoria.sh backup-now >> logs/vm-backup.log 2>&1
```

改动备份配置后请跑一次 `just vm-backup-restore-test` —— **没验证过恢复的备份不算备份**。

---

## 六、时序库备份与恢复 (`scripts/victoria.sh`)

备份是**按需动作**而非常驻服务（常驻 `vmbackup` 守护容器已移除），全部能力集中在 `scripts/victoria.sh`，由 justfile 配方委托调用：

| 配方 | 说明 |
| :--- | :--- |
| `just vm-backup-now` | 通过 `/snapshot/create` 建瞬时快照，增量备份到 `${DATA_PATH}victoria-backup/latest`，完成后自动删除快照 |
| `just vm-backup-restore-test` | 恢复演练：恢复到隔离目录 + 临时实例比对 `count(up)`，不触碰生产数据 |
| `just vm-restore` | 灾难恢复：旧数据改名留存 `victoria.bak.<时间戳>` 后再覆盖，可人工回滚 |

### 1. 等价手工备份命令

```bash
docker run --rm --network backend \
  -v ${DATA_PATH}victoria:/storage:ro \
  -v ${DATA_PATH}victoria-backup:/backup \
  victoriametrics/vmbackup:v1.151.0 \
  -storageDataPath=/storage \
  -snapshot.createURL=http://victoria-metrics:8428/snapshot/create \
  -dst=fs:///backup/latest
```

备份源目录为只读挂载，不阻塞读写；如需备份到 S3/MinIO，改 `-dst=s3://<bucket>/<path>` 并注入 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`（自建 MinIO 追加 `-customS3Endpoint=http://minio:9000`）。

### 2. 运维核查

```bash
ls -lh ${DATA_PATH:-./data/}victoria-backup/latest   # 备份集内容
curl http://localhost:8428/snapshot/list             # 应为 {"status":"ok","snapshots":[]}
```

### 3. 定时备份

需要周期性备份时交给宿主 cron / systemd timer 调 `just vm-backup-now`，不再为此常驻一个容器。
