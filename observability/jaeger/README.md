# Jaeger v2 链路追踪数据面 (官方镜像，按需启用)

直接使用官方 `jaegertracing/jaeger` 镜像（v2 系列，本质是 OpenTelemetry Collector 发行版），单容器承担
**OTLP 摄取 + badger 持久化 + 查询 API/UI**，不引入任何自建镜像。

> **当前状态：只入库、不启用。** 编排、Caddy 路由、vmagent 抓取任务三处均为注释态，
> 现役链路数据面仍是 `victoria-traces/`。需要时按下方「启用步骤」一次打开。

---

## 为什么不能像数据源那样指向 VictoriaTraces

Jaeger v2 的 UI 只能查询**自己配置的存储**：

- 它的 Remote Storage 是 **gRPC Storage API v2**（用于接入自定义存储后端），不是「把 UI 指向另一个 Jaeger 的 HTTP API」；
- VictoriaTraces 只提供 HTTP 的 Jaeger Query JSON API（`/select/jaeger/api`），不实现该 gRPC Storage 接口。

因此本目录是「自包含数据面」形态，与 `victoria-traces/` 是**替换关系**，不是叠加。

---

## 端口

| 端口 | 用途 | 是否发布到宿主机 |
| :--- | :--- | :--- |
| `16686` | 查询 API + Jaeger UI | 是（`${JAEGER_UI_PORT:-16686}`） |
| `4318` | OTLP/HTTP 摄取 | 是（`${JAEGER_OTLP_HTTP_PORT:-4318}`），供宿主机侧应用上报 |
| `4317` | OTLP/gRPC 摄取 | 否（`victoria-traces` 已占用该宿主机端口），容器间用 `jaeger:4317` |
| `13133` | `healthcheckv2` 的 `/status` | 否，仅容器内 healthcheck |
| `8888` | Jaeger 自身 Prometheus 指标 | 否，由 vmagent 抓取 `jaeger:8888/metrics` |

## 配置要点 (`config.yaml`)

裁剪自官方 `cmd/jaeger/config-badger.yaml`，只保留本栈需要的部分：

- `extensions`：`jaeger_storage`（badger 后端 `traces_store`）+ `jaeger_query` + `healthcheckv2`；
- `badger.directories.keys/values` 指向 `/storage/badger/**`（挂载 `${DATA_PATH}jaeger`）；
- `ephemeral: false` 落盘持久化，`ttl.spans: 168h`（7 天，对齐 VictoriaTraces 原 `retentionPeriod=7d`）；
- 未启用：`jaeger`/`zipkin` 旧协议接收、`remote_sampling` 自适应采样、AI/MCP、pprof。

> `user: "0"` 的原因：badger 以镜像默认用户（uid `10001`）无法写入属主为 root 的 bind mount，
> 官方文档专有该故障项；本机开发栈沿用 `iam/zitadel` 的写法。

---

## 启用步骤 (四处)

1. `observability/docker-compose.yml`：取消注释 `# - jaeger/docker-compose.yml`；
2. `gateways/caddy/Caddyfile`：取消注释 `#import proxy-app-auth jaeger.{$SITE_ADDRESS} jaeger:16686`；
3. `observability/victoria-agent/prometheus.yml`：取消注释 `jaeger` 抓取任务；
4. Grafana 数据源：当前 `victoriametrics`/`victoriatraces` 不变，按下面「数据源选择」二选一。

```bash
docker compose up -d jaeger
docker compose restart grafana   # 仅在改了数据源预配时需要
```

### 数据源选择（启用前请先验证）

实测（`jaegertracing/jaeger:2.21.0`）该镜像的查询接口**不是** v1 形态：

| 路径 | 结果 |
| :--- | :--- |
| `/api/v3/services`、`/api/v3/operations` | `200`（v3 查询 API，UI 走这套） |
| `/api/dependencies`、`/api/traces/{id}` | `200`（仍提供） |
| `/api/services`、`/api/operations`、`/api/traces?...` | `404`（v1 列表类接口已移除） |

因此：

- **Jaeger 自带 UI 一定可用**（`http://localhost:16686`，与 v3 接口自洽）；
- **Grafana 内置 Jaeger 数据源用的是 v1 列表类接口**，指向 Jaeger v2 时服务/操作下拉与检索可能失效 ——
  启用后请实测：可用则把 `victoriatraces_ds.yaml` 的 `url` 改为 `http://jaeger:16686`（无需路径改写），
  不可用则保留 VictoriaTraces 作为 Grafana 侧数据源、Jaeger 仅作为库与其自带 UI。

---

## 常用运维指令

```bash
# 启动 / 重启
docker compose up -d jaeger
docker compose restart jaeger

# 探活（healthcheckv2）
docker inspect --format '{{.State.Health.Status}}' jaeger
curl -s http://localhost:16686/api/v3/services         # 查询 API（v3）

# 确认 badger 已落盘
ls -lh "${DATA_PATH:-./data/}jaeger/badger"

# 自身指标（端口未对外发布，需进容器）
docker exec jaeger wget -qO- http://127.0.0.1:8888/metrics | head
```
