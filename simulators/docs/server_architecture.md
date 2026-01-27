# IoT 售货机服务端架构设计 (Server Architecture)

本文档定义了冷链便当售货机云端数据处理与监控系统的整体架构设计。

---

## 1. 技术栈总览

| 组件 | 镜像版本 | 用途 | 端口 |
| :--- | :--- | :--- | :--- |
| **Mosquitto** | `eclipse-mosquitto:2.0.22-openssl` | MQTT 5.0 Broker | 1883, 8883 (TLS) |
| **Telegraf** | `telegraf:1.37` | 数据采集代理 (MQTT → TimescaleDB) | - |
| **TimescaleDB** | `timescale/timescaledb:latest-pg18` | 时序数据库 (基于 PostgreSQL 18) | 5432 |
| **Grafana** | `grafana/grafana:12.3.0` | 可视化监控仪表盘 | 3000 |

---

## 2. 系统架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           IoT 售货机设备层                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │ VM-SH-001│  │ VM-SH-002│  │ VM-BJ-001│  │ VM-GZ-001│  ...           │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘                │
│       │             │             │             │                       │
│       └─────────────┴──────┬──────┴─────────────┘                       │
│                            │ MQTT 5.0 (QoS 0/1/2)                       │
└────────────────────────────┼────────────────────────────────────────────┘
                             ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        服务端数据层 (Docker Compose)                    │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Mosquitto (MQTT Broker)                        │  │
│  │  - 端口: 1883 (TCP), 8883 (TLS), 9001 (WebSocket)                │  │
│  │  - 主题订阅: v1/vm/+/telemetry, v1/vm/+/events, v1/vm/+/status   │  │
│  └───────────────────────────┬──────────────────────────────────────┘  │
│                              │                                          │
│                              ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Telegraf (数据采集代理)                        │  │
│  │  - 输入: MQTT Consumer (订阅所有 v1/vm/# 主题)                   │  │
│  │  - 解析: JSON Parser                                              │  │
│  │  - 输出: TimescaleDB (PostgreSQL 协议写入)                        │  │
│  └───────────────────────────┬──────────────────────────────────────┘  │
│                              │                                          │
│                              ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                TimescaleDB (时序数据库)                           │  │
│  │  - 基于 PostgreSQL 18                                             │  │
│  │  - 超表 (Hypertable): vm_telemetry, vm_events, vm_status         │  │
│  │  - 自动分区: 按时间 (1 天一个分区)                                │  │
│  │  - 数据保留策略: 遥测 30 天, 事件 90 天                           │  │
│  └───────────────────────────┬──────────────────────────────────────┘  │
│                              │                                          │
│                              ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Grafana (可视化监控)                           │  │
│  │  - 数据源: TimescaleDB (PostgreSQL)                               │  │
│  │  - 仪表盘: 设备概览、温度趋势、告警统计                           │  │
│  │  - 告警规则: 超温、离线、暴力告警                                 │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. 数据流详解

### 3.1 遥测数据流 (Telemetry)

```
设备 → MQTT (v1/vm/{device_no}/telemetry, QoS 0)
     → Telegraf (mqtt_consumer 插件)
     → JSON 解析 (提取 system, environment, connectivity, location)
     → TimescaleDB (vm_telemetry 超表)
     → Grafana (实时仪表盘)
```

### 3.2 事件数据流 (Events)

```
设备 → MQTT (v1/vm/{device_no}/events, QoS 1)
     → Telegraf (mqtt_consumer 插件)
     → JSON 解析 (提取 event_type, data)
     → TimescaleDB (vm_events 超表)
     → Grafana (告警面板 + 通知规则)
```

### 3.3 状态数据流 (Status)

```
设备 → MQTT (v1/vm/{device_no}/status, QoS 1, Retain)
     → Telegraf (mqtt_consumer 插件)
     → TimescaleDB (vm_status 超表)
     → Grafana (设备在线状态面板)
```

---

## 4. 数据库 Schema 设计

### 4.1 遥测数据表 (vm_telemetry)

```sql
CREATE TABLE vm_telemetry (
    time            TIMESTAMPTZ NOT NULL,
    device_no       TEXT NOT NULL,
    voltage         DOUBLE PRECISION,
    current         DOUBLE PRECISION,
    uptime          INTEGER,
    door_closed     BOOLEAN,
    freezer_temp_0  DOUBLE PRECISION,
    freezer_temp_1  DOUBLE PRECISION,
    freezer_temp_2  DOUBLE PRECISION,
    freezer_temp_3  DOUBLE PRECISION,
    ambient_temp    DOUBLE PRECISION,
    vibration_g     DOUBLE PRECISION,
    rssi            INTEGER,
    lat             DOUBLE PRECISION,
    lng             DOUBLE PRECISION
);

-- 转换为超表 (按时间自动分区)
SELECT create_hypertable('vm_telemetry', 'time');

-- 创建索引
CREATE INDEX idx_telemetry_device ON vm_telemetry (device_no, time DESC);

-- 数据保留策略 (30 天)
SELECT add_retention_policy('vm_telemetry', INTERVAL '30 days');
```

### 4.2 事件数据表 (vm_events)

```sql
CREATE TABLE vm_events (
    time            TIMESTAMPTZ NOT NULL,
    device_no       TEXT NOT NULL,
    event_type      TEXT NOT NULL,
    order_id        TEXT,
    channel_id      TEXT,
    oven_id         TEXT,
    error_code      TEXT,
    image_url       TEXT,
    video_url       TEXT,
    raw_data        JSONB
);

SELECT create_hypertable('vm_events', 'time');
CREATE INDEX idx_events_device ON vm_events (device_no, time DESC);
CREATE INDEX idx_events_type ON vm_events (event_type, time DESC);

-- 数据保留策略 (90 天)
SELECT add_retention_policy('vm_events', INTERVAL '90 days');
```

### 4.3 状态数据表 (vm_status)

```sql
CREATE TABLE vm_status (
    time            TIMESTAMPTZ NOT NULL,
    device_no       TEXT NOT NULL,
    status          TEXT NOT NULL,
    firmware        TEXT,
    hardware        TEXT
);

SELECT create_hypertable('vm_status', 'time');
CREATE INDEX idx_status_device ON vm_status (device_no, time DESC);
```

---

## 5. Telegraf 配置

```toml
# /etc/telegraf/telegraf.conf

[agent]
  interval = "10s"
  flush_interval = "10s"

# ==================== 输入: MQTT Consumer ====================
[[inputs.mqtt_consumer]]
  servers = ["tcp://mosquitto:1883"]
  topics = [
    "v1/vm/+/telemetry",
    "v1/vm/+/events",
    "v1/vm/+/status"
  ]
  qos = 1
  data_format = "json_v2"

  [[inputs.mqtt_consumer.topic_parsing]]
    topic = "v1/vm/+/telemetry"
    measurement = "vm_telemetry"
    tags = "_/_/device_no/_"

  [[inputs.mqtt_consumer.topic_parsing]]
    topic = "v1/vm/+/events"
    measurement = "vm_events"
    tags = "_/_/device_no/_"

  [[inputs.mqtt_consumer.topic_parsing]]
    topic = "v1/vm/+/status"
    measurement = "vm_status"
    tags = "_/_/device_no/_"

  [[inputs.mqtt_consumer.json_v2]]
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "system.voltage"
      rename = "voltage"
      type = "float"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "system.current"
      rename = "current"
      type = "float"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "system.uptime"
      rename = "uptime"
      type = "int"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "system.door_closed"
      rename = "door_closed"
      type = "bool"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "environment.freezer_temps.0"
      rename = "freezer_temp_0"
      type = "float"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "environment.freezer_temps.1"
      rename = "freezer_temp_1"
      type = "float"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "environment.freezer_temps.2"
      rename = "freezer_temp_2"
      type = "float"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "environment.freezer_temps.3"
      rename = "freezer_temp_3"
      type = "float"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "environment.ambient_temp"
      rename = "ambient_temp"
      type = "float"
    [[inputs.mqtt_consumer.json_v2.field]]
      path = "connectivity.rssi"
      rename = "rssi"
      type = "int"

# ==================== 输出: TimescaleDB ====================
[[outputs.postgresql]]
  connection = "postgres://iot:iot_password@timescaledb:5432/iot_vending?sslmode=disable"
  create_templates = []
  add_column_templates = []
  tag_As_Jsonb = false
```

---

## 6. Grafana 监控面板

### 6.1 设备概览仪表盘

| 面板 | 查询示例 | 用途 |
| :--- | :--- | :--- |
| **在线设备数** | `SELECT COUNT(DISTINCT device_no) FROM vm_status WHERE status='online' AND time > now() - '5 min'` | 实时在线统计 |
| **今日订单数** | `SELECT COUNT(*) FROM vm_events WHERE event_type='DISPENSE_SUCCESS' AND time > now()::date` | 业务指标 |
| **活跃告警** | `SELECT * FROM vm_events WHERE event_type IN ('CHANNEL_JAM','HEATING_FAILURE') AND time > now() - '1 hour'` | 故障监控 |
| **设备分布地图** | `SELECT device_no, lat, lng FROM vm_telemetry WHERE time > now() - '5 min'` | 地理位置 |

### 6.2 温度监控面板

```sql
-- 冷冻温区趋势图
SELECT 
    time_bucket('5 minutes', time) AS bucket,
    device_no,
    AVG(freezer_temp_0) AS zone_0,
    AVG(freezer_temp_1) AS zone_1,
    AVG(freezer_temp_2) AS zone_2,
    AVG(freezer_temp_3) AS zone_3
FROM vm_telemetry
WHERE time > now() - '24 hours'
GROUP BY bucket, device_no
ORDER BY bucket;
```

### 6.3 告警规则配置

| 告警名称 | 条件 | 通知渠道 |
| :--- | :--- | :--- |
| **设备离线** | `vm_status.status = 'offline'` 持续 5 分钟 | 钉钉/企业微信 |
| **冷冻超温** | `freezer_temp_* > -10` | 短信 + 邮件 |
| **暴力告警** | `event_type = 'VANDALISM_ALERT'` | 电话 + 短信 |

---

## 7. 容器编排 (Docker Compose)

详见 `docker-compose.server.yml` 文件。

---

## 8. 扩展性设计

### 8.1 水平扩展

*   **MQTT Broker**: 使用 EMQX 集群替代单节点 Mosquitto
*   **TimescaleDB**: 启用多节点分布式模式
*   **Telegraf**: 每个区域部署独立实例

### 8.2 高可用设计

*   **数据库**: PostgreSQL 流复制 + Patroni 自动故障转移
*   **Grafana**: 多实例 + 共享 PostgreSQL 后端
*   **MQTT**: 主备模式 + VIP 漂移

---
*Created by Antigravity - IoT Backend Architecture*
