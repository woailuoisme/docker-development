# IoT 实时推送系统：Centrifugo v6 (WSS) 接口规范

本方案使用 **Centrifugo v6** 作为实时推送引擎，将从 MQTT 代理（Mosquitto）汇聚到后端的 IoT 消息，通过 **WSS (WebSocket Secure)** 协议实时推送到 Web/App 管理后台。

---

## 1. 基础信息 (General)

| 配置项 | 开发环境 | 生产环境 | 说明 |
| :--- | :--- | :--- | :--- |
| **WSS 地址** | `ws://localhost:8000/connection/websocket` | `wss://api.your-domain.com/connection/websocket` | 实时长连接地址 |
| **HTTP API 地址** | `http://localhost:8000/api` | `https://api.your-domain.com/api` | 后端调用推送接口 |
| **协议版本** | Centrifugo v6 | Centrifugo v6 | 采用 JSON 模式通讯 |
| **认证方式** | JWT (HMAC) | JWT (HMAC/RSA) | 客户端连接必须携带 Token |

---

## 2. 客户端连接与认证 (Authentication)

### 2.1 JWT 载荷 (Claims)
前端连接 WSS 前，由后端签发 JWT Token。

```json
{
  "sub": "admin_user_01",     // 用户唯一标识
  "exp": 1737868800,          // 过期时间
  "channels": ["public"],     // (可选) 允许自动订阅的频道
  "info": {                   // 附加元数据
    "role": "manager",
    "name": "管理员"
  }
}
```

### 2.2 建立连接 (JavaScript 示例)
```javascript
const centrifuge = new Centrifuge('ws://localhost:8000/connection/websocket', {
    token: 'YOUR_JWT_TOKEN' // 从后端获取
});

centrifuge.on('connected', (ctx) => {
    console.log('✓ 已建立 WSS 实时连接', ctx.client);
});

centrifuge.connect();
```

---

## 3. 频道设计 (Channel Architecture)

Centrifugo 使用命名空间区分不同类型的数据流。

| 命名空间 | 格式 | 描述 |
| :--- | :--- | :--- |
| `telemetry` | `telemetry:{vm_id}` | 售货机实时遥测数据流 (温湿度、电压等) |
| `events` | `events:{vm_id}` | 业务关键事件流 (出餐、告警、上线) |
| `p_alert` | `p_alert:global` | 全局紧急告警广播 |
| `user_cmd` | `user_cmd:{user_id}` | 针对特定用户的回执通知 |

---

## 4. 实时监控接口 (Client Subscriptions)

### 4.1 订阅设备遥测 (`telemetry`)
**频道名**: `telemetry:VM-SH-001`

**消息结构 (JSON)**:
```json
{
    "id": "VM-SH-001",
    "system": { "voltage": 224.2, "door_closed": true },
    "environment": { "temps": [-18.5, -18.2] },
    "ts": "2026-01-26T14:50:00Z"
}
```

### 4.2 订阅设备事件 (`events`)
**频道名**: `events:VM-SH-001`

**典型场景**: 当设备检测到“暴力震动”或“出餐成功”时，前端 UI 立即弹出提示。

---

## 5. 服务端推送 API (Server API)

后端服务在接收到 MQTT 消息并处理入库后，通过此 API 转发给 Centrifugo。

### 5.1 推送单频道消息 (`publish`)
**Endpoint**: `POST /api`
**Headers**: `Authorization: Token {APIKEY}`

**Body**:
```json
{
  "method": "publish",
  "params": {
    "channel": "telemetry:VM-SH-001",
    "data": {
       "voltage": 221.5,
       "msg": "实时电压波动"
    }
  }
}
```

### 5.2 广播消息 (`broadcast`)
用于全向所有在线管理员推送停机维护通知。

**Body**:
```json
{
  "method": "broadcast",
  "params": {
    "channels": ["p_alert:global"],
    "data": {
      "level": "P0",
      "content": "服务器集群将于凌晨 2 点进行系统升级"
    }
  }
}
```

---

## 6. 特性：Presence 与 History (高级功能)

| 功能 | 方法 | 用途 |
| :--- | :--- | :--- |
| **在线统计 (Presence)** | `presence(channel)` | 查询当前有多少个管理员在监控某台机器 |
| **消息回溯 (History)** | `history(channel)` | 页面刷新后，获取最近 10 条该机器的历史状态 |

---

## 7. 性能优化建议

1.  **二进制协议**: 对于超大规模并发（>10万连接），建议改用 Protobuf 模式。
2.  **Proxy 模式**: Centrifugo v6 支持代理订阅逻辑，可以直接通过 HTTP 请求后端授权频道访问权限。
3.  **WSS 证书**: 生产环境务必强制 TLS 加密，防止 IoT 数据在公网被嗅探。

---
*Created by Antigravity - Centrifugo Integration Specialist*
