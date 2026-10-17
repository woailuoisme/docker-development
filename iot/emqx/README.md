# EMQX (云原生分布式 MQTT 5.0 消息中枢与控制台)

本项目集成全球领先的开源分布式物联网 MQTT 消息服务器 [EMQX 5.8](https://github.com/emqx/emqx)，为大规模 IoT 设备连接、双向消息传输与边缘数据转发提供高并发、高可用底座。

---

## 🌟 核心特性与优势

- **完整 MQTT 5.0 协议标准**：原生支持 MQTT 5.0 与 3.1.1 规范，提供主题别名、用户属性、共享订阅与会话过期间隔等高级能力。
- **现代化可视化 Web 控制台 (Dashboard)**：自带现代化控制台（默认端口 `18083`），支持连接客户端实时监控、消息追踪、速率限制与告警诊断。
- **内置数据集成与规则引擎 (Rule Engine)**：无需编写胶水代码，直接在控制台使用 SQL 处理海量消息，支持低延迟转存至 InfluxDB、PostgreSQL、ClickHouse、Kafka 或转发至 eKuiper。
- **毫秒级连接性能与高并发**：基于 Erlang/OTP 软实时并发运行时设计，单节点可稳定承载海量并发长连接与吞吐。

---

## 🏗️ 端口与持久化规范

### 1. 端口映射

| 协议 / 功能 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **MQTT TCP** | `1883` | `1883:1883` | 标准 MQTT 协议通信端口 (若与 Mosquitto 同时运行请二选一) |
| **MQTT WebSocket** | `8083` | `8083:8083` | 前端 Web 浏览器 / 微信小程序直连 MQTT 端口 |
| **MQTT SSL/TLS** | `8883` | `8883:8883` | 加密安全的 MQTT 传输层端口 |
| **Dashboard Web UI** | `18083` | `18083:18083` | EMQX Web 管理与流数据规则控制台 |

### 2. 持久化数据与日志路径

持久化路径遵循全局规范：

| 宿主机路径 | 容器内挂载路径 | 说明 |
| :--- | :--- | :--- |
| `${DATA_PATH}emqx/data` | `/opt/emqx/data` | 节点运行时状态、客户端鉴权与规则引擎持久化 |
| `${LOG_PATH}emqx/log` | `/opt/emqx/log` | EMQX 运行日志与审计日志目录 |

---

## 🚀 快速启动与访问

### 1. 启动服务

```bash
# 启动 EMQX 单独立项服务
docker compose up -d emqx

# 查看运行状态与健康检查
docker compose ps emqx
```

### 2. 控制台访问与凭证

- **本地访问**：浏览器访问 [http://localhost:18083](http://localhost:18083)
- **Caddy 反代访问**：域名预留 `emqx.{$SITE_ADDRESS}`（在 `gateways/caddy/Caddyfile` 取消对应注释）
- **默认管理员凭证**：
  - 用户名：由 `.env` 中 `MQTT_USERNAME` 注入（默认 `admin`）
  - 密码：由 `.env` 中 `MQTT_PASSWORD` 注入（默认 `admin123!`）
  - *首次在控制台登录后可按系统提示更新或绑定 API Key*

---

## 🔗 与其他组件的协同方案

- **与 eKuiper 流计算协同**：eKuiper 可直接将源 Source 配置为 `tcp://emqx:1883`，以极低延迟订阅海量设备上报消息并执行复杂 SQL 规则。
- **与 InfluxDB / 时序库协同**：可利用 EMQX 内置 Data Integration 功能或通过 Telegraf 订阅 MQTT 主题转存写入 InfluxDB 3。
