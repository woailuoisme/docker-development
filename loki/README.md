# Grafana Loki - 高性能日志聚合引擎

Grafana Loki 是一个水平可扩展、高可用、多租户的日志聚合系统。受 Prometheus 启发，Loki 不对日志正文进行全文索引，而是仅索引日志流的元数据标签（Labels），从而大幅降低资源消耗和存储成本。

---

## 快速导航

- **服务端口**：`3100` (HTTP API) / `9096` (gRPC)
- **容器名称**：`loki`
- **配置文件**：`loki/local-config.yaml`
- **数据持久化**：`${DATA_PATH}loki`

---

## 架构与核心特性

1. **存储引擎**：基于 `tsdb` (Schema v13) 和原生文件系统（Filesystem）存储日志 Chunks，轻量高效。
2. **生命周期治理**：集成 `compactor`，默认保留 31 天（744h）历史日志，并自动压缩历史数据。
3. **安全与网络**：
   - 接入内部 `backend` 网络，供 Fluent Bit 推送日志及 Grafana 查询。
   - 接入外部 `frontend` 网络，可通过 Caddy 进行安全鉴权代理访问。

---

## 常用 LogQL 查询示例

在 Grafana Explore 中选择 `Loki` 数据源后，可以使用 LogQL 进行查询：

### 1. 基础日志检索

```logql
# 查询指定容器日志
{container_name="php-roadrunner"}

# 包含特定错误关键字
{job="fluent-bit"} |= "error"

# 排除心跳检测日志
{job="fluent-bit"} !~ "health.*check"
```

### 2. JSON 结构化解析与过滤

```logql
# 解析 JSON 日志并按 HTTP 状态码过滤
{job="fluent-bit"} | json | status >= 500

# 提取关键字段格式化展示
{job="fluent-bit"} | json | line_format "{{.level | upper}} [{{.app}}] {{.message}}"
```

### 3. 指标化时序计算 (Metric Queries)

```logql
# 统计过去 5 分钟内各容器的错误日志生成速率
sum by (container_name) (rate({job="fluent-bit"} |= "error" [5m]))

# 统计总日志写入吞吐量
sum(rate({job="fluent-bit"}[1m]))
```

---

## 常用维护命令

```bash
# 检查配置语法是否合法
docker run --rm -v "${PWD}/local-config.yaml:/etc/loki/local-config.yaml:ro" grafana/loki:3.7 -verify-config=true -config.file=/etc/loki/local-config.yaml

# 查看 Loki 服务运行就绪状态
curl -s http://localhost:3100/ready
```
