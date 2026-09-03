# Fluent Bit - 高性能多协议日志采集与传输代理

Fluent Bit 是一个极轻量、快速且内存友好的日志收集与转发代理。在本项目中，Fluent Bit 承担数据采集总线角色，统一收集容器 stdout/stderr、应用挂载日志及 HTTP 上报，并推送给 Grafana Loki。

---

## 快速导航

- **Forward 端口 (Docker 驱动)**：`24224` (TCP/UDP)
- **HTTP 摄取端口**：`9880`
- **监控指标端口**：`2020`
- **容器名称**：`fluent-bit`
- **配置文件**：`fluent-bit/fluent-bit.conf`、`fluent-bit/parsers.conf`

---

## 日志接入方式 (三种途径)

### 途径 1：Docker 容器标准输出 (推荐)

在任意业务服务的 `docker-compose.yml` 中添加 `logging` 配置块，将 stdout/stderr 实时重定向至 Fluent Bit：

```yaml
services:
  my-service:
    image: my-service:latest
    container_name: my-service
    logging:
      driver: fluentd
      options:
        fluentd-address: "localhost:24224"
        tag: "docker.{{.Name}}"
```

> **说明**：Docker 引擎将自动携带容器名和元数据通过 Fluentd Forward 协议投递至 Fluent Bit。

### 途径 2：应用本地日志文件 (Tail 模式)

将应用的日志目录挂载至宿主机的 `${LOG_PATH}`（如 `${LOG_PATH}my-service:/var/log/my-service`）：

Fluent Bit 已默认挂载 `${LOG_PATH}:/var/log/apps:ro`，其内部的 `[INPUT]` tail 插件会自动递归匹配 `/var/log/apps/**/*.log`，并在 Loki 中携带 `source=file_tail` 与对应文件名。

### 途径 3：HTTP REST API 上报

应用、Node 脚本或 Shell 钩子可通过 HTTP 直接发送结构化 JSON 日志：

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"message": "User login success", "level": "info", "user_id": 10086, "app": "auth"}' \
  http://localhost:9880/app.log
```

---

## 常用命令

```bash
# 检查配置文件语法是否合法
docker run --rm -v "${PWD}:/fluent-bit/etc:ro" fluent/fluent-bit:latest /fluent-bit/bin/fluent-bit --dry-run -c /fluent-bit/etc/fluent-bit.conf

# 查看 Fluent Bit 内部健康与度量状态
curl -s http://localhost:2020/api/v1/health
curl -s http://localhost:2020/api/v1/metrics
```
