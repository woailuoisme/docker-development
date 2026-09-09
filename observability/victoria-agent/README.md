# vmagent 指标抓取与分发代理 (Metrics Collector & Forwarder)

`vmagent` 是 VictoriaMetrics 官方出品的超轻量、低开销且具备高弹性的指标抓取与传输代理。在本项目架构中，它负责替代单体抓取，将指标轮询逻辑完全解耦，专职执行全部系统/中间件探针的拉取，并通过 `remote_write` 协议安全推送到 VictoriaMetrics。

---

## 📌 核心特性与架构定位

1. **极低资源消耗**：
   - 相比原生 Prometheus Agent 节省多达 80% 的内存消耗，常态下运行仅需 10MB ~ 30MB 内存。
2. **本地磁盘断网缓冲 (Disk Buffer)**：
   - 配置 `-remoteWrite.tmpDataPath=/tmpData`，即使后端 VictoriaMetrics 重启或网络发生闪断，`vmagent` 会自动将采集到的指标缓冲在本地持久卷中，网络恢复后无缝排空补齐，绝不遗漏监控数据。
3. **100% 兼容 Prometheus 配置**：
   - 完全支持 Prometheus 标准的 `scrape_configs` 语法、服务发现与重打标（Relabeling）机制。
4. **内置轻量级 Web 控制台**：
   - 监听端口 `8429`，提供 `/targets` 实时状态、`/metrics` 自监控指标以及调试接口。

---

## 🏗️ 采集流转拓扑

```mermaid
flowchart LR
    subgraph 监控目标群 (Scrape Targets)
        NodeExp[node-exporter :9100]
        CAdv[cadvisor :8080]
        ValkeyExp[valkey-exporter :9121]
        PGExp[postgres-exporter :9187]
        Caddy[caddy :2019]
        Vector[vector :8686]
        VM[victoria-metrics :8428]
        VLogs[victoria-logs :9428]
        VMAlert[vmalert :8880]
    end

    subgraph vmagent 实例 :8429
        Scraper[内置 Promscrape 抓取引擎]
        Buffer[(本地磁盘缓冲区 /tmpData)]
        Scraper -->|抓取完成| Buffer
    end

    NodeExp -->|HTTP GET /metrics| Scraper
    CAdv -->|HTTP GET /metrics| Scraper
    ValkeyExp -->|HTTP GET /metrics| Scraper
    PGExp -->|HTTP GET /metrics| Scraper
    Caddy -->|HTTP GET /metrics| Scraper
    Vector -->|HTTP GET /metrics| Scraper
    VM -->|HTTP GET /metrics| Scraper
    VLogs -->|HTTP GET /metrics| Scraper
    VMAlert -->|HTTP GET /metrics| Scraper

    Buffer -->|remote_write POST| VMStore[(VictoriaMetrics TSDB :8428)]
```

---

## ⚙️ 核心参数与配置文件

服务定义于 `observability/victoria-agent/docker-compose.yml`：

- **镜像**：`victoriametrics/vmagent:v1.151.0`
- **端口映射**：`${VMAGENT_PORT:-8429}:8429`
- **启动参数解析**：
  - `-promscrape.config=/etc/prometheus/prometheus.yml`：指定抓取规则配置文件。
  - `-remoteWrite.url=http://victoria-metrics:8428/api/v1/write`：远端写入端点。
  - `-remoteWrite.tmpDataPath=/tmpData`：启用本地磁盘防丢缓冲。
  - `-httpListenAddr=:8429`：HTTP 服务监听端口。
  - `-memory.allowedPercent=60`：内存软保护上限。
- **挂载卷**：
  - `${DATA_PATH}victoria-agent:/tmpData`：磁盘缓冲落盘持久化。
  - `${CONFIG_PATH}observability/victoria-agent/prometheus.yml:/etc/prometheus/prometheus.yml:ro`：抓取配置。

---

## 🚀 常用端点与运维指南

### 1. HTTP API 与状态端点

| 端点路径 | 协议 | 描述 |
| :--- | :--- | :--- |
| `http://localhost:8429/targets` | HTTP Web | 查看当前全部抓取任务状态、健康度、最近耗时 |
| `http://localhost:8429/metrics` | HTTP API | `vmagent` 自身的 Prometheus 监控指标 |
| `http://localhost:8429/health` | HTTP API | 健康检查接口（200 OK） |
| `http://localhost:8429/api/v1/targets` | HTTP API | 返回 JSON 格式的 Target 运行数据 |

### 2. 常用操作命令

```bash
# 启动 vmagent
docker compose up -d vmagent

# 实时查看抓取与写入日志
docker compose logs -f vmagent

# 修改 prometheus.yml 后热重载配置（无需重启容器）
docker compose exec vmagent kill -HUP 1

# 检查当前抓取 Target 的健康状态
curl -s http://localhost:8429/targets | grep -i "state"
```
