# LiveKit 现代化开源 WebRTC 实时音视频与 AI 交互基础设施

[LiveKit](https://github.com/livekit/livekit) 是目前全球最流行、现代化、高扩展性的开源 **WebRTC SFU (Selective Forwarding Unit)** 实时通信平台。专为**多人音视频会议、屏幕共享、超低延迟实时互动、元宇宙空间音频**以及 **Realtime AI 实时语音/多模态交互 Agent**（如 OpenAI Realtime API 开源替代、LiveKit Voice Agents）而设计。

---

## 🎯 为什么需要 LiveKit？核心架构与优势

| 维度 | **LiveKit (WebRTC SFU 互动平台)** | **MediaMTX (流媒体转封装网关)** |
| :--- | :--- | :--- |
| **架构定位** | **实时交互通信基础设施 (SFU)** | **全协议流媒体路由中枢 (Routing Gateway)** |
| **典型场景** | 多人视频会议、实时语音房、多人屏幕共享、**Realtime AI 实时语音大模型对话**、协同白板 | 监控摄像头 RTSP 汇聚、工业相机、OBS 推流分发、直播拉流播放 |
| **交互模式** | **双向/多向多人毫秒级实时交互** (Pub-Sub Room 模型) | **单向广播式推流与大规模分发** (1推多拉) |
| **媒体拓扑** | 房间 (Room) $\rightarrow$ 轨道 (Track) $\rightarrow$ 参与者 (Participant) | 路径 (Path) $\rightarrow$ 流 (Stream) |
| **端到端延迟** | **< 100ms** (全球低延迟 WebRTC) | 100ms ~ 3s (取决于 WebRTC/HLS/RTSP) |
| **AI 原生支持** | **原生提供 LiveKit Agents 框架** (语音转文字、LLM、文字转语音全双工毫秒级响应) | 需自行拉取原始 RTSP 流送入 OpenCV/YOLO |

---

## 🏛️ LiveKit 完整应用架构

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             1. 客户端交互层 (Client Layer)                       │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • Web 浏览器 (React / Vue / Svelte / Vanilla JS SDK)                            │
│  • 移动端跨平台 (Flutter / React Native / iOS Swift / Android Kotlin SDK)        │
│  • 桌面端应用 (Electron / Rust / Unity / Unreal Engine SDK)                      │
│  • Realtime AI Agent (Python / Node.js LiveKit Agents Framework)                 │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 1. 请求房间加入 Token (带身份与房间名)
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   2. 业务服务端鉴权层 (Backend Service Layer)                    │
│                        (NestJS / Go Fiber / Laravel)                             │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 用户身份认证与房间权限校验 (JWT / RBAC)                                       │
│  • 使用 API Key / Secret 签发 LiveKit AccessToken (`livekit-server-sdk`)         │
│  • 服务端房间生命周期管理 (创建房间、踢人、静音、录制 Egress 控制)               │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 2. 携带 AccessToken 连接
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                     3. 网关反向代理层 (Caddy Ingress / Proxy)                    │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • HTTPS / WSS 证书自动化与 SSL 卸载                                             │
│  • 统一反代 WebSocket 信令流量 (`wss://livekit.example.com` -> `livekit:7880`)   │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 3. WebSocket 信令 (7880) + UDP 媒体流 (50000-50100)
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                        4. LiveKit SFU 核心服务集群                               │
│                         (livekit/livekit-server)                                 │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • WebRTC 媒体轨道精准路由与带宽自适应 (SVC / Simulcast / Dynacast)              │
│  • 内置 STUN / TURN 穿透服务 (7882/udp) 与 TCP 媒体回退 (7881)                   │
│  • 全双工数据通道 (DataChannel) 实时文本/控制信令广播                            │
└───────────────────┬──────────────────────────────────────────────▲───────────────┘
                    │                                              │
                    │ 4. 共享房间元数据与节点间路由                │ 5. 实时语音打断与多模态流
                    ▼                                              ▼
┌────────────────────────────────────────┐     ┌───────────────────────────────────┐
│     5. 状态存储与集群协同 (Redis)      │     │   6. 实时 AI Agent 计算中枢       │
│  • 房间状态共享、分布式节点发现        │     │   • STT (Deepgram/Whisper)        │
│  • Webhook 事件分发与消息 Pub/Sub      │     │   • LLM (Claude/GPT-4o/Ollama)    │
│                                        │     │   • TTS (Cartesia/ElevenLabs)     │
└────────────────────────────────────────┘     └───────────────────────────────────┘
```

---

## 🔌 端口与传输协议映射

| 宿主机端口 | 容器内部端口 | 传输层 | 协议与用途 |
| :--- | :--- | :--- | :--- |
| `7880` | `7880` | TCP / HTTP | **WebSocket 客户端信令通道** + REST API 端口 |
| `7881` | `7881` | TCP | **RTC over TCP 回退传输** (在极端严格防火墙禁止 UDP 时使用) |
| `7882` | `7882` | UDP | **内置 STUN / TURN 服务器** (处理 NAT 复杂网络穿透) |
| `50000-50100` | `50000-50100` | UDP | **WebRTC 音视频媒体流传输端口范围 (RTP/RTCP)** |

---

## 💻 业务服务端签发 Token 示例 (Node.js & Go)

客户端不能直接拥有 LiveKit Secret，必须由业务服务端按需签发包含房间权限的 JWT Token：

### 1. TypeScript / Node.js 签发 Token

```typescript
import { AccessToken } from 'livekit-server-sdk';

export async function createLiveKitToken(roomName: string, participantName: string): Promise<string> {
  const apiKey = process.env.LIVEKIT_API_KEY || 'devkey';
  const apiSecret = process.env.LIVEKIT_API_SECRET || 'secretsecretsecretsecretsecretsecret';

  const at = new AccessToken(apiKey, apiSecret, {
    identity: participantName,
    ttl: '10m', // Token 10分钟有效
  });

  // 赋予进入房间及发布/订阅音视频权限
  at.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });

  return await at.toJwt();
}
```

### 2. Go 签发 Token

```go
package main

import (
	"time"

	"github.com/livekit/protocol/auth"
)

func GenerateLiveKitToken(apiKey, apiSecret, roomName, identity string) (string, error) {
	at := auth.NewAccessToken(apiKey, apiSecret)
	grant := &auth.VideoGrant{
		RoomJoin:     true,
		Room:         roomName,
		CanPublish:   true,
		CanSubscribe: true,
	}
	at.AddGrant(grant).
		SetIdentity(identity).
		SetValidFor(10 * time.Minute)

	return at.ToJWT()
}
```

---

## 🛠️ 启动与管理

### 启动 LiveKit 服务

```bash
docker compose up -d livekit
```

### 查看实时运行日志

```bash
docker compose logs -f livekit
```

### 接入 Caddy 反向代理网关

在 `caddy/Caddyfile` 中配置子域名反代：

```caddyfile
import proxy-app livekit.{$SITE_ADDRESS} livekit:7880
```
