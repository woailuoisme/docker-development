# IoT 智能售货机：MQTT 5.0 接口通讯规范 (V1.0)

本手册定义了售货机终端（客户端）与云端（服务端）之间的 MQTT 通讯协议。所有实现必须依照 **MQTT 5.0** 标准。

---

## 1. 连接规范 (Connection)

### 1.1 基础信息

| 配置项 | 值 | 说明 |
| :--- | :--- | :--- |
| Broker 地址 | `mqtt.your-domain.com` | 生产环境域名 |
| 本地测试地址 | `localhost` 或 `mosquitto` | Docker 容器名 |
| TCP 端口 | `1883` | 非加密连接 |
| TLS 端口 | `8883` | 加密连接 (推荐生产使用) |
| 协议版本 | `MQTT 5.0` | 必须显式指定 |
| 编码格式 | `UTF-8` | 所有 JSON Payload |
| Keep Alive | `60` 秒 | 心跳间隔 |

### 1.2 认证参数

| 参数 | 格式 | 示例 | 说明 |
| :--- | :--- | :--- | :--- |
| Username | `{device_sn}` | `VM-SH-001` | 机身唯一序列号 |
| Password | `{token}` | `eyJhbGciOi...` | 由后台签发的 JWT Token |
| Client ID | `VM_{sn}_{rand}` | `VM_SH001_a3f2` | 加入随机后缀避免重复 |

### 1.3 遗嘱消息 (LWT) 配置

当设备异常断开时，Broker 自动发布此消息。

| 配置项 | 值 | 说明 |
| :--- | :--- | :--- |
| Topic | `v1/vm/{device_no}/status` | 状态主题 |
| QoS | `1` | 确保至少送达一次 |
| Retain | `true` | 新订阅者可立即获取最新状态 |

**Payload:**

```json
{
  "status": "offline",
  "device_no": "VM-SH-001",
  "reason": "unexpected",
  "ts": 1737868800
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `status` | string | 是 | 固定为 `"offline"` |
| `device_no` | string | 是 | 设备唯一标识 |
| `reason` | string | 否 | 断开原因：`unexpected` (异常) / `maintenance` (维护) |
| `ts` | integer | 是 | Unix 时间戳 (秒) |

---

## 2. 接口总览

| 序号 | 主题 (Topic) | 方向 | QoS | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| 2.1 | `v1/vm/{device_no}/telemetry` | 设备 → 服务端 | 0 | 定时上报健康状态 |
| 2.2 | `v1/vm/{device_no}/events` | 设备 → 服务端 | 1 | 上报业务事件 |
| 2.3 | `v1/vm/{device_no}/status` | 设备 → 服务端 | 1 | 在线状态维护 |
| 2.4 | `v1/vm/{device_no}/commands` | 服务端 → 设备 | 2 | 下发控制指令 |
| 2.5 | `v1/vm/{device_no}/commands/ack` | 设备 → 服务端 | 1 | 指令执行结果回复 |

---

## 3. 接口详细定义

---

### 3.1 设备遥测 (Telemetry)

**接口路径:** `v1/vm/{device_no}/telemetry`

**方向:** 设备 → 服务端

**QoS:** `0` (最多一次)

**发布频率:** 建议 10~30 秒/次

**MQTT 5.0 Properties:**

| 属性 | 值 | 说明 |
| :--- | :--- | :--- |
| `ContentType` | `application/json` | 内容类型 |
| `UserProperty` | `priority=low` | 消息优先级标记 |

#### 完整 Payload 结构

```json
{
  "device_no": "VM-SH-001",
  "ts": "2026-01-26T13:25:00Z",
  "system": {
    "voltage": 222.5,
    "current": 1.25,
    "uptime": 3600,
    "door_closed": true
  },
  "environment": {
    "freezer_temps": [-18.5, -18.2, -18.8, -17.5],
    "ambient_temp": 26.5,
    "vibration_g": 0.05
  },
  "connectivity": {
    "rssi": -65,
    "type": "4G",
    "csq": 24
  },
  "location": {
    "lat": 31.2304,
    "lng": 121.4737
  }
}
```

#### 字段说明

**根级字段:**

| 字段 | 类型 | 必填 | 单位 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `device_no` | string | 是 | - | 设备唯一标识，格式: `VM-{地区}-{编号}` |
| `ts` | string | 是 | ISO8601 | 采集时间，UTC 时区 |

**system 对象:**

| 字段 | 类型 | 必填 | 单位 | 有效范围 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `voltage` | float | 是 | V (伏特) | 180~260 | 输入电压，低于 200V 或高于 240V 应告警 |
| `current` | float | 是 | A (安培) | 0~20 | 总电流，微波炉工作时可达 8A |
| `uptime` | integer | 是 | 秒 | ≥0 | 自上次重启后的运行时长 |
| `door_closed` | boolean | 是 | - | true/false | 机门状态：`true`=关闭，`false`=打开 |

**environment 对象:**

| 字段 | 类型 | 必填 | 单位 | 有效范围 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `freezer_temps` | float[] | 是 | ℃ | -30 ~ 0 | 4 路冷冻温区采样，索引 0-3 对应物理位置 |
| `ambient_temp` | float | 是 | ℃ | -40 ~ 60 | 机身外部环境温度 |
| `vibration_g` | float | 是 | g | 0 ~ 16 | 三轴加速度计合成值，>2.0 表示剧烈撞击 |

**connectivity 对象:**

| 字段 | 类型 | 必填 | 单位 | 有效范围 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `rssi` | integer | 是 | dBm | -120 ~ -40 | 信号强度，<-100 表示信号极差 |
| `type` | string | 是 | - | 4G/5G/WiFi | 当前网络类型 |
| `csq` | integer | 否 | - | 0~31 | GSM 信号质量等级 (可选) |

**location 对象:**

| 字段 | 类型 | 必填 | 单位 | 有效范围 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `lat` | float | 是 | 度 | -90 ~ 90 | 纬度，WGS84 坐标系 |
| `lng` | float | 是 | 度 | -180 ~ 180 | 经度，WGS84 坐标系 |

#### 模拟实现 (Node.js)

```javascript
sendTelemetry() {
    if (!this.client.connected) return;
    
    // 构造遥测 Payload
    const payload = {
        id: this.device_no,
        ts: new Date().toISOString(),
        system: {
            voltage: parseFloat((this.voltage + (Math.random() - 0.5)).toFixed(1)),
            current: parseFloat((this.current + (Math.random() - 0.5) * 0.2).toFixed(2)),
            uptime: this.uptime,
            door_closed: this.doorClosed
        },
        environment: {
            freezer_temps: this.freezerTemps,
            ambient_temp: this.ambientTemp,
            vibration_g: this.vibrationG
        },
        connectivity: {
            rssi: this.rssi,
            type: '4G',
            csq: Math.floor((this.rssi + 113) / 2)
        },
        location: {
            lat: parseFloat((this.location.lat + (Math.random() - 0.5) * 0.0001).toFixed(6)),
            lng: parseFloat((this.location.lng + (Math.random() - 0.5) * 0.0001).toFixed(6))
        }
    };
    
    // MQTT 5.0 特性配置
    const options = {
        qos: 0,
        properties: {
            contentType: 'application/json',
            userProperties: { priority: 'low' }
        }
    };
    
    this.client.publish(`${this.baseTopic}/telemetry`, JSON.stringify(payload), options);
}
```

---

### 3.2 关键事件 (Events)

**接口路径:** `v1/vm/{device_no}/events`

**方向:** 设备 → 服务端

**QoS:** `1` (至少一次)

**触发时机:** 业务动作完成或硬件异常时立即发送

**MQTT 5.0 Properties:**

| 属性 | 值 | 说明 |
| :--- | :--- | :--- |
| `ContentType` | `application/json` | 内容类型 |
| `UserProperty` | `priority=high` | 高优事件 |

#### 事件类型枚举

| event_type | 优先级 | 触发条件 |
| :--- | :--- | :--- |
| `DISPENSE_SUCCESS` | 中 | 出餐成功 |
| `DISPENSE_FAILED` | 高 | 出餐失败 (无红外感应) |
| `CHANNEL_JAM` | 高 | 货道卡住 (电机过载) |
| `HEATING_FAILURE` | 高 | 微波炉加热失效 |
| `DOOR_OPENED` | 高 | 机门被打开 |
| `VANDALISM_ALERT` | 紧急 | 暴力摇晃告警 |
| `TEMP_OVERHEAT` | 高 | 冷冻温区超温 |
| `SNAPSHOT_CAPTURED` | 低 | 抓拍图片完成 |

#### 通用事件推送代码 (Node.js)

```javascript
sendEvent(eventType, data) {
    const payload = {
        event_type: eventType,
        data,
        ts: Math.floor(Date.now() / 1000)
    };
    const options = {
        qos: 1,
        properties: {
            contentType: 'application/json',
            userProperties: { 
                priority: eventType.includes('FAIL') || eventType.includes('JAM') ? 'high' : 'normal' 
            }
        }
    };
    this.client.publish(`${this.baseTopic}/events`, JSON.stringify(payload), options);
}
```

---

#### 3.2.1 事件: DISPENSE_SUCCESS (出餐成功)

**描述:** 完整的出餐流程执行成功后上报。

```json
{
  "event_type": "DISPENSE_SUCCESS",
  "data": {
    "order_id": "ORD20260126001",
    "meal_cid": "M-12",
    "sauce_cid": "S-02",
    "oven_id": "OVEN_A",
    "heat_duration": 90,
    "image_url": "https://oss.example.com/vm01/dispense_001.jpg"
  },
  "ts": 1737868855
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `event_type` | string | 是 | 固定为 `DISPENSE_SUCCESS` |
| `data.order_id` | string | 是 | 关联的订单号 |
| `data.meal_cid` | string | 是 | 便当货道编号，格式: `M-{01~48}` |
| `data.sauce_cid` | string | 是 | 调料货道编号，格式: `S-{01~05}` |
| `data.oven_id` | string | 是 | 使用的微波炉，`OVEN_A` 或 `OVEN_B` |
| `data.heat_duration` | integer | 是 | 实际加热时长 (秒) |
| `data.image_url` | string | 否 | 出餐口抓拍图片 URL |
| `ts` | integer | 是 | 事件发生时间 (Unix 时间戳) |

---

#### 3.2.2 事件: CHANNEL_JAM (货道卡住)

**描述:** 电机电流过载或红外未感应到掉落时触发。

```json
{
  "event_type": "CHANNEL_JAM",
  "data": {
    "channel_id": "M-24",
    "motor_current": 4.8,
    "error_code": "E103",
    "image_url": "https://oss.example.com/vm01/jam_001.jpg"
  },
  "ts": 1737868890
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `event_type` | string | 是 | 固定为 `CHANNEL_JAM` |
| `data.channel_id` | string | 是 | 故障货道编号 |
| `data.motor_current` | float | 是 | 故障时电机电流峰值 (A) |
| `data.error_code` | string | 是 | 错误码，见附录 |
| `data.image_url` | string | 否 | 故障瞬间抓拍 |
| `ts` | integer | 是 | 事件发生时间 |

---

#### 3.2.3 事件: HEATING_FAILURE (加热失效)

**描述:** 微波炉功率异常低 (磁控管失效) 时触发。

```json
{
  "event_type": "HEATING_FAILURE",
  "data": {
    "oven_id": "OVEN_B",
    "expected_power": 1100,
    "actual_power": 25,
    "exhaust_temp": 22.5
  },
  "ts": 1737868900
}
```

| 字段 | 类型 | 必填 | 单位 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `data.oven_id` | string | 是 | - | 故障微波炉编号 |
| `data.expected_power` | integer | 是 | W | 预期工作功率 |
| `data.actual_power` | integer | 是 | W | 实测功率 |
| `data.exhaust_temp` | float | 是 | ℃ | 排气口温度 (未升温判定失效) |

---

#### 3.2.4 事件: VANDALISM_ALERT (暴力告警)

**描述:** 加速度计检测到剧烈撞击时触发。

```json
{
  "event_type": "VANDALISM_ALERT",
  "data": {
    "g_force": 3.5,
    "image_url": "https://oss.example.com/vm01/alert_001.jpg",
    "video_url": "https://oss.example.com/vm01/alert_001.mp4"
  },
  "ts": 1737868920
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `data.g_force` | float | 是 | 触发时的合成 G 值 |
| `data.image_url` | string | 否 | 顶部摄像头抓拍 |
| `data.video_url` | string | 否 | 告警前后 10 秒短视频 |

---

### 3.3 状态维护 (Status)

**接口路径:** `v1/vm/{device_no}/status`

**方向:** 设备 → 服务端

**QoS:** `1`

**Retain:** `true`

**触发时机:** 设备上线时主动发布；异常断开时由 Broker 自动发布 LWT。

#### 上线消息

```json
{
  "status": "online",
  "device_no": "VM-SH-001",
  "firmware": "5.0.1",
  "hardware": "v3.2",
  "ts": 1737868800
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `status` | string | 是 | `online` 或 `offline` |
| `device_no` | string | 是 | 设备唯一标识 |
| `firmware` | string | 否 | 固件版本号 |
| `hardware` | string | 否 | 硬件版本号 |
| `ts` | integer | 是 | 状态变更时间 |

#### 在线状态同步代码 (Node.js)

```javascript
publishStatus(status) {
    const payload = {
        status,
        id: this.device_no,
        firmware: this.firmware, // "5.0.1"
        hardware: this.hardware, // "v3.2"
        ts: Math.floor(Date.now() / 1000)
    };
    this.client.publish(`${this.baseTopic}/status`, JSON.stringify(payload), { qos: 1, retain: true });
}
```

---

### 3.4 指令下发 (Commands)

**接口路径:** `v1/vm/{device_no}/commands`

**方向:** 服务端 → 设备

**QoS:** `2` (精确一次)

**MQTT 5.0 Properties:**

| 属性 | 值 | 说明 |
| :--- | :--- | :--- |
| `MessageExpiryInterval` | `60` | 消息有效期 (秒) |
| `ResponseTopic` | `v1/vm/{device_no}/commands/ack` | 响应主题 |
| `CorrelationData` | `{cmd_id}` | 关联 ID |

#### 指令类型枚举

| action | 用途 | 风险等级 |
| :--- | :--- | :--- |
| `DISPENSE` | 执行出餐 | 中 |
| `START_VIDEO` | 开启实时视频 | 低 |
| `STOP_VIDEO` | 关闭实时视频 | 低 |
| `REBOOT` | 重启设备 | 高 |
| `LOCK_CHANNEL` | 锁定货道 | 中 |
| `UNLOCK_CHANNEL` | 解锁货道 | 中 |
| `SET_CONFIG` | 修改配置 | 高 |

---

#### 3.4.1 指令: DISPENSE (出餐)

**描述:** 执行一次完整的出餐流程。

```json
{
  "cmd_id": "CMD20260126001",
  "action": "DISPENSE",
  "params": {
    "order_id": "ORD20260126001",
    "meal_cid": "M-10",
    "sauce_cid": "S-01",
    "oven_id": "OVEN_A",
    "heat_seconds": 90
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `cmd_id` | string | 是 | 唯一指令 ID，用于幂等校验 |
| `action` | string | 是 | 固定为 `DISPENSE` |
| `params.order_id` | string | 是 | 关联订单号 |
| `params.meal_cid` | string | 是 | 便当货道，`M-01` ~ `M-48` |
| `params.sauce_cid` | string | 是 | 调料货道，`S-01` ~ `S-05` |
| `params.oven_id` | string | 是 | 微波炉选择，`OVEN_A` 或 `OVEN_B` |
| `params.heat_seconds` | integer | 是 | 加热时长 (秒)，范围 30~180 |

---

#### 3.4.2 指令: START_VIDEO (开启视频)

**描述:** 开启实时视频推流。

```json
{
  "cmd_id": "CMD20260126002",
  "action": "START_VIDEO",
  "params": {
    "camera_id": "CAM_TOP",
    "stream_url": "rtmp://media.example.com/live/vm01",
    "duration": 120
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `params.camera_id` | string | 是 | 摄像头编号：`CAM_TOP` (顶部) / `CAM_DISPENSE` (出餐口) |
| `params.stream_url` | string | 是 | 推流目标地址 |
| `params.duration` | integer | 是 | 自动关闭时长 (秒)，最大 300 |

---

#### 3.4.3 指令: REBOOT (重启)

**描述:** 远程重启设备。

```json
{
  "cmd_id": "CMD20260126003",
  "action": "REBOOT",
  "params": {
    "delay": 5,
    "reason": "firmware_update"
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `params.delay` | integer | 否 | 延迟重启秒数，默认 0 |
| `params.reason` | string | 否 | 重启原因，用于日志记录 |

#### 指令监听处理代码 (Node.js)

```javascript
// 在 connect 回调中订阅核心指令主题 (QoS 2)
this.client.subscribe(`${this.baseTopic}/commands`, { qos: 2 });

// 指令分发逻辑
this.client.on('message', (topic, message) => {
    try {
        const payload = JSON.parse(message.toString());
        const { cmd_id, action, params = {} } = payload;
        
        // 幂等性检查 (缓存最近指令)
        if (this.cmdCache.includes(cmd_id)) return;
        this.cmdCache.push(cmd_id);
        
        switch (action) {
            case 'DISPENSE': this.handleDispense(cmd_id, params); break;
            case 'REBOOT': this.handleReboot(cmd_id, params); break;
            case 'LOCK_CHANNEL': this.handleLockChannel(cmd_id, params); break;
            // ... 根据需要处理其他指令
        }
    } catch (e) {
        console.error(`[ERROR] Command processing failed: ${e.message}`);
    }
});
```

---

### 3.5 指令响应 (Command ACK)

**接口路径:** `v1/vm/{device_no}/commands/ack`

**方向:** 设备 → 服务端

**QoS:** `1`

**触发时机:** 收到指令后立即回复执行状态。

```json
{
  "cmd_id": "CMD20260126001",
  "status": "success",
  "result": {
    "executed_at": 1737868860,
    "duration_ms": 95000
  },
  "error": null
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `cmd_id` | string | 是 | 对应的指令 ID |
| `status` | string | 是 | `success` / `failed` / `rejected` |
| `result` | object | 否 | 执行结果详情 |
| `result.executed_at` | integer | 否 | 执行完成时间 |
| `result.duration_ms` | integer | 否 | 执行耗时 (毫秒) |
| `error` | object | 否 | 失败时的错误信息 |
| `error.code` | string | 否 | 错误码 |
| `error.message` | string | 否 | 错误描述 |

#### 指令响应代码 (Node.js)

```javascript
sendAck(cmdId, status, result = null, error = null) {
    const payload = { cmd_id: cmdId, status, result, error };
    this.client.publish(`${this.baseTopic}/commands/ack`, JSON.stringify(payload), { qos: 1 });
}
```

**失败示例:**

```json
{
  "cmd_id": "CMD20260126001",
  "status": "failed",
  "result": null,
  "error": {
    "code": "E103",
    "message": "Channel M-10 is jammed"
  }
}
```

---

## 4. 错误码附录

| 错误码 | 说明 | 建议处理 |
| :--- | :--- | :--- |
| `E101` | 货道库存为空 | 通知补货人员 |
| `E102` | 红外传感器未感应 | 检查货道是否卡住 |
| `E103` | 电机电流过载 | 锁定货道，人工检修 |
| `E201` | 微波炉功率异常 | 切换至备用微波炉 |
| `E202` | 微波炉超时 | 检查门锁传感器 |
| `E301` | 冷冻温区超温 | 检查压缩机状态 |
| `E401` | GPS 信号丢失 | 检查天线连接 |
| `E501` | 摄像头离线 | 检查摄像头供电 |

---

## 5. 开发注意事项

1. **幂等性保证:** 设备必须缓存最近 100 条 `cmd_id`，对重复指令直接返回 ACK 而不重新执行。
2. **超时处理:** 若指令 60s 内未收到 ACK，服务端应判定为超时并记录。
3. **大文件限制:** MQTT Payload 禁止超过 256KB，图片/视频必须上传至 OSS 后传递 URL。
4. **网络重连:** 断线后使用指数退避算法重连 (1s, 2s, 4s... 最大 60s)。

---

### *Created by Antigravity - Advanced Agentic Coding Assistant*
