# MediaMTX 实时全协议流媒体服务器

MediaMTX (原 rtsp-simple-server) 是一个零依赖、高性能的实时媒体服务器和多协议路由网关。支持 RTSP、RTMP、HLS、WebRTC、SRT 和 RIST 等主流协议的实时互转与低延迟分发。

---

## 🏛️ 客户端 - MediaMTX - 服务端 完整应用架构图

在构建企业级音视频应用（如智慧安防、工业远程遥控、AI 视觉推理、直播系统）时，**客户端、MediaMTX 流媒体中枢与业务服务端**的分工与完整数据交互架构如下：

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    1. 客户端层 (Client Layer)                                     │
├────────────────────────────────────────┬─────────────────────────────────────────────────────────┤
│          【推流采集端 (Publishers)】   │                 【拉流播放端 (Players / Viewers)】      │
│  • 安防 / 工业摄像头 (RTSP)            │  • PC 监控大屏 / Web 界面 (WebRTC WHEP - 200ms)         │
│  • OBS / 桌面采播软件 (RTMP / SRT)     │  • 移动端 App / 微信 H5 (HLS / LL-HLS)                  │
│  • 网页端摄像头直推 (WebRTC WHIP)      │  • 远程操作工位 / 控制手柄 (WebRTC 双向交互)             │
│  • 无人机 / 车载图传盒 (SRT / RIST)    │  • 运维调试与工程终端 (VLC / FFmpeg / RTSP)             │
└───────────────────┬────────────────────┴───────────────────────────▲─────────────────────────────┘
                    │                                                │
                    │ 媒体推流 (RTSP/RTMP/SRT/WHIP)                  │ 媒体拉流 (WebRTC/HLS/RTSP)
                    ▼                                                │
┌────────────────────────────────────────────────────────────────────┴─────────────────────────────┐
│                            2. 网关与接入层 (Caddy Ingress / Reverse Proxy)                        │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│  • SSL/TLS 证书自动化与安全卸载 (HTTPS / WSS)                                                    │
│  • 统一域名与子域名路由转发 (`live.example.com` -> MediaMTX / `api.example.com` -> 后端服务)    │
│  • Web 静态资源托管 (Vue / React / SPA 前端构建产物)                                             │
│  • 前置访问控制与安全策略 (Authelia SSO / IP 白名单 / CORS 跨域治理)                              │
└───────────────────┬────────────────────────────────────────────────▲─────────────────────────────┘
                    │                                                │
        ┌───────────┴────────────────────────┐       ┌───────────────┴─────────────────────────┐
        │                                    │       │                                         │
        ▼                                    │       │                                         │
┌─────────────────────────────────────────┐  │       │  ┌───────────────────────────────────┐  │
│  3. 流媒体中枢层 (MediaMTX)             │  │       │  │ 4. 业务服务端 (Backend App Service)│  │
│  (bluenviron/mediamtx)                  │  │       │  │ (NestJS / Go Fiber / Laravel)     │  │
├─────────────────────────────────────────┤  │       │  ├───────────────────────────────────┤  │
│ • 零拷贝多协议解包与转封装 (Transmuxing)│  │       │  │ • 用户权限与角色校验 (RBAC / JWT) │  │
│ • WebRTC ICE 信令与媒体通道 (8889/8189) │  │       │  │ • 设备资产台账与流路径生命周期管理│  │
│ • 动态按需拉流引擎 (runOnDemand)        │  │       │  │ • 播放 Token 签发与推流权限校验   │  │
│ • 录像自动切片与本地缓存 (.mp4 / .ts)   │  │       │  │ • PTZ 云台控制信令透传 (ONVIF)    │  │
│ • HTTP 鉴权与生命周期 Hook 触发器       │  │       │  │ • 实时统计、计费与在线设备监控     │  │
└───────────────────┬─────────────────────┘  │       │  └─────────────────┬─────────────────┘  │
                    │                        │       │                    │                    │
                    │ ① HTTP 鉴权 (POST /auth)│       │                    │                    │
                    ├────────────────────────┴───────┼────────────────────┤                    │
                    │                                │                    │                    │
                    │ ② 流就绪/断开 Hook (POST /events)                   │                    │
                    ├────────────────────────────────────────────────────>│                    │
                    │                                                     │                    │
                    │ ③ REST API 查询流状态/踢人                          │                    │
                    │<────────────────────────────────────────────────────┤                    │
                    │                                                     │                    │
                    ▼ (可选: 原始视频流转推分析)                          │ ⑤ 告警/事件        │
┌─────────────────────────────────────────┐                               │                    │
│  5. 视觉智能分析层 (AI / CV Inference)  │                               │                    │
│  (Python YOLOv8 / OpenCV / DeepStream)  │ ──── ④ 结构化识别事件上报 ────>│                    │
├─────────────────────────────────────────┤                               │                    │
│ • 实时拉取原始流并进行目标/人脸/缺陷检测│                               │                    │
│ • 将带画框与识别信息的流推回 MediaMTX   │                               │                    │
└─────────────────────────────────────────┘                               │                    │
                                                                          │                    │
┌─────────────────────────────────────────────────────────────────────────▼────────────────────▼───┐
│                                6. 数据与持久化层 (Storage & Persistence Layer)                    │
├────────────────────────────────────────┬──────────────────────────────────────────────────────────┤
│   关系型数据库 (PostgreSQL / MySQL)    │   缓存与消息中间件 (Redis)                               │
│   • 设备配置与流地址关系映射           │   • 播放 Token 快速比对与分布式锁                        │
│   • 告警历史记录与用户操作审计日志     │   • 设备在线状态心跳与实时在线人数统计                   │
│   • 录像元数据索引与分片记录           │   • WebSocket / SSE 实时事件广播发布订阅 (Pub/Sub)       │
├────────────────────────────────────────┴──────────────────────────────────────────────────────────┤
│   对象存储服务 (Garage S3 / Cloudflare R2 / 阿里云 OSS)                                          │
│   • 录像切片文件永久冷归档 (`.mp4` / `.ts`)                                                       │
│   • 抓拍告警截图与证据链保存                                                                      │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 核心业务时序交互流程

### 1. 推流端接入与鉴权流程 (Publish & Auth Flow)

```text
[ 推流设备 (IPC/OBS) ]          [ MediaMTX ]           [ 业务后端 (NestJS/Fiber) ]     [ 数据库 / Redis ]
          │                          │                              │                         │
          │ 1. 发起推流 (带 Token)    │                              │                         │
          │─────────────────────────>│                              │                         │
          │ (如: rtsp://.../cam01)   │ 2. HTTP POST /auth (鉴权)    │                         │
          │                          │─────────────────────────────>│                         │
          │                          │                              │ 3. 校验设备合法性与密钥 │
          │                          │                              │────────────────────────>│
          │                          │                              │<────────────────────────│
          │                          │ 4. HTTP 200 OK (通过)        │                         │
          │                          │<─────────────────────────────│                         │
          │ 5. 建立媒体流通道 (就绪)  │                              │                         │
          │<════════════════════════>│ 6. Hook POST /events (就绪)  │                         │
          │                          │─────────────────────────────>│                         │
          │                          │                              │ 7. 更新设备为「在线」   │
          │                          │                              │ 8. WS 广播「推流上线」  │
```

### 2. Web 端低延时拉流播放流程 (WebRTC WHEP Playback Flow)

```text
[ Web 播放端 / 监控大屏 ]       [ 业务后端 ]               [ MediaMTX ]              [ 摄像头 / 源端 ]
          │                          │                          │                           │
          │ 1. 请求播放凭证 (Token)  │                          │                           │
          │─────────────────────────>│                          │                           │
          │ 2. 返回专属播放 URL + Token                         │                           │
          │<─────────────────────────│                          │                           │
          │                          │                          │                           │
          │ 3. 发起 WebRTC WHEP SDP 交换 (带 Token)             │                           │
          │────────────────────────────────────────────────────>│                           │
          │                          │ 4. HTTP POST /auth 鉴权  │                           │
          │                          │<─────────────────────────│                           │
          │                          │ 5. 校验通过 (200 OK)     │                           │
          │                          │─────────────────────────>│                           │
          │                          │                          │ (若配置 runOnDemand)      │
          │                          │                          │ 6. 向源头按需拉流         │
          │                          │                          │──────────────────────────>│
          │                          │                          │<══════════════════════════│
          │ 7. 返回 SDP Answer (建立 WebRTC UDP 通道)           │                           │
          │<────────────────────────────────────────────────────│                           │
          │ 8. 接收 WebRTC 媒体流 (端到端延迟 < 200ms)          │                           │
          │<════════════════════════════════════════════════════│                           │
```

---

## 🌐 支持的协议矩阵与应用场景全景

MediaMTX 充当多协议流媒体路由中枢，能够实现**任意输入协议转换为任意输出协议**。下表为各协议的技术特性与最匹配的业务场景：

| 协议名称 | 传输层 | 典型延迟 | 浏览器原生支持 | 核心应用场景 |
| :--- | :--- | :--- | :--- | :--- |
| **WebRTC** (WHEP/WHIP) | HTTP + UDP (DTLS/SRTP) | **100ms ~ 300ms** (超低延迟) | ✅ 全平台免插件原生支持 | • PC/移动端监控大屏秒级实时预览<br>• AGV/无人机/矿卡远程低延迟遥操作 (Teleoperation)<br>• 浏览器端摄像头免插件推流 (WHIP)<br>• 远程手术与医疗互动示教 |
| **RTSP** | TCP / UDP / Multicast | **0.5s ~ 2s** | ❌ (需转封装) | • 海康/大华/宇视等安防 IPC 摄像头标准接入<br>• NVR / DVR 硬盘录像机流汇聚<br>• 工控机与工业相机采集<br>• Python OpenCV / YOLO AI 视觉推理管道输入 |
| **RTMP / RTMPS** | TCP (TLS 加密) | **1s ~ 3s** | ❌ (需转封装) | • OBS Studio / vMix 主播端专业直播推流<br>• 云桌面 / 云手机画面低延迟推流<br>• 跨平台多路转推（分发至 Bilibili、YouTube、微信视频号） |
| **HLS / LL-HLS** | HTTP / HTTPS (TCP) | 标准 3~10s<br>LL-HLS 1~2s | ✅ iOS / Safari 原生，前端 Hls.js | • 微信公众号 / 小程序 / 移动 H5 跨端自适应播放<br>• 百万级海量并发大规模分发 (接入 CDN 边缘缓存)<br>• 录像回放、切片归档与点播回看 |
| **SRT** | UDP (ARQ 重传 + AES) | **0.5s ~ 1.5s** | ❌ (需转封装) | • 户外无人机 4G/5G 弱网超视距高清图传<br>• 跨国 / 跨省远距离公网长途推流传输<br>• 广电应急转播车与野外单兵音视频回传 |
| **RIST** | UDP (VSF 广播标准) | **0.5s ~ 1.5s** | ❌ (需转封装) | • 专业广电演播厅多厂商硬件编解码器信号对接<br>• 广播电视台主备信号点对点保真中继 |
| **树莓派 Camera** | CSI 硬件总线 | **< 100ms** | ❌ (直采输入) | • 嵌入式边缘采集盒 (树莓派 + 官方摄像头直驱)<br>• 3D 打印机看护、智能猫眼、创客轻量 IoT 节点 |

---

## 🎯 为什么后端开发需要 MediaMTX？

在音视频与实时通信开发中，后端工程师经常面临协议割裂、高延迟与繁琐转码的痛点。MediaMTX 作为一个即插即用的轻量级流媒体中枢，提供了以下核心价值：

### 1. 全协议零成本互相转封装 (Multi-Protocol Routing)

- **痛点**：传统摄像头输出 RTSP，OBS 常用 RTMP，广播设备偏好 SRT，而现代浏览器仅原生支持 WebRTC 和 HLS。
- **价值**：任意协议推流进入 MediaMTX，服务器在内存中进行**零拷贝解包与重新封装**（无 CPU 密集型重转码开销），同时输出所有其他协议，瞬间打通端到端协议鸿沟。

### 2. 毫秒级低延迟 Web 直连 (Sub-Second WebRTC / LL-HLS)

- **痛点**：传统 HLS/RTMP 延迟通常在 3~10 秒以上，无法满足实时操控与低延迟互动需求。
- **价值**：内置 WebRTC WHEP (拉流) / WHIP (推流) 标准，浏览器可通过原生 `<video>` 标签在 200ms~500ms 内实现超低延迟直连播放，无需 Flash 或重型播放器插件。

### 3. 与业务后端无缝联动 (Webhooks & API)

- **鉴权与事件通知**：支持配置外部 HTTP Webhooks（如推流鉴权、拉流鉴权、流上线/下线通知），方便与 Laravel / Go / Node.js 业务系统做用户权限校验与在线状态监控。
- **按需拉流 (On-Demand Pull)**：支持配置 `runOnDemand`，仅在有前端用户连接拉流时才向源头设备拉取视频流，极大节省服务器带宽与边缘设备的硬件负载。

### 4. 极致轻量与生产高并发 (Go-Native)

- 单一 Go 二进制实现，底噪内存仅几十 MB，单个实例即可稳定承载数千路并发流分发，非常适合容器化微服务编排。

---

## 🏭 最流行的工业生产环境落地场景

在工业 4.0、智能制造、物联网与能源重工业中，MediaMTX 因其**超低资源消耗、低延迟、抗弱网（SRT）和零依赖**的特性，被广泛部署于工控机（IPC）、边缘网关（NVIDIA Jetson / 树莓派）及中心控制室：

```text
[ 边缘工控机 / 车载终端 ]          [ 5G 专网 / 工业 WiFi ]            [ 调度集控中心 ]
┌─────────────────────────┐                                 ┌─────────────────────────┐
│ 工业相机 / AGV / 机械臂 │ ───> [ MediaMTX 边缘节点 ] ───> │ 远程驾驶舱 / Web 大屏   │
└─────────────────────────┘      (就地分析 & 协议封装)      └─────────────────────────┘
```

### 1. 工业机器视觉与产线缺陷检测 (Machine Vision & QA)

- **现场环境**：半导体晶圆检测、3C 电子 PCB 产线、汽车焊装流水线。
- **业务流程**：高帧率工业相机（GigE Vision / RTSP）采集工件图像 $\rightarrow$ 边缘工控机 MediaMTX 分发 $\rightarrow$ 产线旁工位看板（WebRTC $<200\text{ms}$ 实时监看）+ 现场质检 AI（拉流检测缺陷并实时画框）。

### 2. AGV / AMR 仓储移动机器人与无人叉车第一视角 (FPV 遥控)

- **现场环境**：电商智能仓储、港口自动化码头、大型离散制造车间。
- **业务流程**：AGV 车载摄像头通过 5G/WiFi 专网将 FPV 视频流推至厂区 MediaMTX。调度中控系统可同时预览上百台 AGV 运行视角；当小车避障卡死时，远程操作员可毫秒级低延迟接管远程驾驶。

### 3. 矿山 / 吊机 / 高危作业远程遥操作 (Teleoperation)

- **现场环境**：露天矿山无人矿卡、港口远控岸桥/龙门吊、化工厂危险区域遥控作业。
- **业务流程**：驾驶舱与作业现场距离几公里至几百公里，使用 SRT（抗丢包传输）+ MediaMTX WebRTC（低延迟呈现），将操控端到端延迟控制在 $100\text{ms}\sim 150\text{ms}$ 内，达到“见即所得”的工业操作标准。

### 4. 智能电网、光伏风电与地下管网智能巡检

- **现场环境**：变电站挂轨巡检机器人、海上风电场、长输油气管道爬行器 (CCTV Pipe Crawler)。
- **业务流程**：双光谱（可见光 + 红外热成像）云台摄像头接入 MediaMTX，利用 `runOnDemand` 特性（集控中心点选具体探头时才发起拉流），大幅降低偏远基站的卫星/专线带宽成本。

### 5. 数字化手术室与远程医疗示教 (Telemedicine)

- **现场环境**：三甲医院数字化手术室、远程专家会诊中心。
- **业务流程**：术野摄像机、腹腔镜、手术显微镜通过医用采集卡输出超高清流至 MediaMTX，在院内局域网提供近乎无损无延迟的 WebRTC 会诊转播。

---

## 🌐 工业级“边云协同”整体架构 (Edge-Cloud Federation)

在大型分布式工业场景中，通常采用“**边缘节点汇聚 + 中心云分发**”的双层架构：

```text
================================ 边缘侧 (Edge / Factory LAN) ================================
┌─────────────────┐       RTSP (TCP)       ┌────────────────────────┐
│ 工业相机 / IPC  │ ─────────────────────> │  MediaMTX 边缘代理节点 │ (运行于工控机/Jetson)
└─────────────────┘                        └───────────┬────────────┘
┌─────────────────┐       RTSP / SRT                   │
│ AGV / 巡检终端  │ ───────────────────────────────────┤
└─────────────────┘                                    │
                                                       ├─> 本地车间监控触摸屏 (WebRTC 直连)
                                                       ├─> 产线 AI 缺陷检测 Worker (本地实时闭环)
                                                       │
                                                       ▼ SRT 跨公网安全加密传输
================================ 中心云 / 控制室 (Cloud / Central IDC) ========================
                                                       │
                                                       ▼
                                           ┌────────────────────────┐
                                           │  中心流媒体集群 / Caddy │
                                           └───────────┬────────────┘
                                                       │
                        ┌──────────────────────────────┼──────────────────────────────┐
                        ▼                              ▼                              ▼
              ┌───────────────────┐          ┌───────────────────┐          ┌───────────────────┐
              │ 集团调度中心大屏   │          │ 移动专家协同 App  │          │ Garage S3 对象存储 │
              │ (WebRTC 毫秒级上屏│          │ (HLS / WebRTC)    │          │ (质检视频长期归档) │
              └───────────────────┘          └───────────────────┘          └───────────────────┘
```

---

## 💻 后端实战集成示例 (NestJS & Go Fiber)

MediaMTX 与后端服务集成最核心的方式为 **HTTP Webhook 鉴权**（`authMethod: http`）与 **生命周期事件上报**。每次客户端发起推流 (`publish`) 或拉流 (`read`) 时，MediaMTX 会向后端发送 POST 请求以校验权限。

### 1. TypeScript / NestJS 实战集成

#### 鉴权与事件 Controller

```typescript
import { Controller, Post, Body, HttpCode, HttpStatus, UnauthorizedException, Logger } from '@nestjs/common';

export interface MediaMtxAuthPayload {
  ip: string;
  user?: string;
  password?: string;
  path: string;       // 流路径，例如 "camera-01"
  protocol: string;   // "webrtc" | "rtsp" | "rtmp" | "hls"
  id?: string;
  action: 'publish' | 'read';
  query?: string;     // URL 查询参数，例如 "token=eyJhbGciOi..."
}

@Controller('api/v1/mediamtx')
export class MediaMtxController {
  private readonly logger = new Logger(MediaMtxController.name);

  @Post('auth')
  @HttpCode(HttpStatus.OK)
  async authenticate(@Body() payload: MediaMtxAuthPayload) {
    this.logger.log(`MediaMTX Auth Request: [${payload.action}] on path [${payload.path}] via [${payload.protocol}] from IP [${payload.ip}]`);

    // 1. 从 URL Query 或 password 中提取 Token
    const params = new URLSearchParams(payload.query || '');
    const token = params.get('token') || payload.password;

    // 2. 校验权限 (例如：推流需具备 Admin 权限，拉流需具备对应设备查看权限)
    const isValid = await this.validateStreamAccess(payload.path, payload.action, token);

    if (!isValid) {
      this.logger.warn(`MediaMTX Auth Rejected for path [${payload.path}]`);
      throw new UnauthorizedException('Invalid stream token or permission denied');
    }

    // 返回 200 OK 即代表放行
    return { status: 'ok' };
  }

  @Post('events')
  @HttpCode(HttpStatus.OK)
  async handleStreamEvents(@Body() event: { event: string; path: string }) {
    this.logger.log(`Stream Status Event: [${event.event}] for path: [${event.path}]`);
    // 处理流上线/断开通知（例如更新数据库在线状态、通知前端 WebSocket 房间）
    return { received: true };
  }

  private async validateStreamAccess(path: string, action: 'publish' | 'read', token?: string): Promise<boolean> {
    if (!token) return false;
    // 实际业务中在此调用 JWT 服务或查询 Redis/PostgreSQL 校验 Token 有效期与权限
    return token.startsWith('valid_');
  }
}
```

---

### 2. Go / Fiber 实战集成

#### 高性能鉴权与状态 Hook 处理

```go
package main

import (
	"log"
	"net/url"
	"strings"

	"github.com/gofiber/fiber/v2"
)

type MediaMtxAuthRequest struct {
	IP       string `json:"ip"`
	User     string `json:"user"`
	Password string `json:"password"`
	Path     string `json:"path"`     // 例如 "workshop-agv-01"
	Protocol string `json:"protocol"` // "webrtc", "rtsp", "hls"
	ID       string `json:"id"`
	Action   string `json:"action"`   // "publish" 或 "read"
	Query    string `json:"query"`    // "token=abc123jwt"
}

func SetupMediaMtxRoutes(app *fiber.App) {
	group := app.Group("/api/v1/mediamtx")

	// 1. 核心 HTTP 鉴权端点 (MediaMTX authHTTPAddress)
	group.Post("/auth", func(c *fiber.Ctx) error {
		var req MediaMtxAuthRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid payload"})
		}

		log.Printf("[MediaMTX Hook] Action: %s, Path: %s, Protocol: %s, IP: %s",
			req.Action, req.Path, req.Protocol, req.IP)

		// 解析 URL 参数中的鉴权 Token
		values, _ := url.ParseQuery(req.Query)
		token := values.Get("token")
		if token == "" {
			token = req.Password
		}

		// 业务鉴权校验 (高并发微秒级响应)
		if !verifyToken(req.Path, req.Action, token) {
			log.Printf("[MediaMTX Hook] Rejected: Path=%s Action=%s", req.Path, req.Action)
			return c.Status(fiber.StatusUnauthorized).SendString("Unauthorized")
		}

		// 返回 200 OK 允许连接
		return c.SendStatus(fiber.StatusOK)
	})

	// 2. 流生命周期就绪/断开事件监听
	group.Post("/events", func(c *fiber.Ctx) error {
		type EventPayload struct {
			Event string `json:"event"`
			Path  string `json:"path"`
		}
		var evt EventPayload
		if err := c.BodyParser(&evt); err == nil {
			log.Printf("[MediaMTX Event] Stream %s is now %s", evt.Path, evt.Event)
			// 触发 Redis 状态发布或 WebSocket 广播
		}
		return c.SendStatus(fiber.StatusOK)
	})
}

func verifyToken(path, action, token string) bool {
	if token == "" {
		return false
	}
	// 实际工程中可在此验证 JWT 签名或从 Redis 快速命中缓存
	return strings.HasPrefix(token, "fiber_auth_")
}
```

---

### 3. MediaMTX 对应配置文件配置 (`mediamtx.yml`)

在开启后端鉴权与事件联动时，MediaMTX 配置示例：

```yaml
# 开启 HTTP 鉴权，每次推流/拉流均向后端请求确认
authMethod: http
authHTTPAddress: http://app:3000/api/v1/mediamtx/auth

# 默认全局路径规则配置
paths:
  all:
    # 当流准备就绪（有人推流成功）时向后端发送通知
    runOnReady: curl -s -X POST http://app:3000/api/v1/mediamtx/events -H "Content-Type:application/json" -d '{"event":"ready","path":"$MTX_PATH"}'
    # 当推流断开时向后端发送通知
    runOnUnReady: curl -s -X POST http://app:3000/api/v1/mediamtx/events -H "Content-Type:application/json" -d '{"event":"unready","path":"$MTX_PATH"}'
```

---

## ⚖️ 主流开源流媒体服务选型对比

| 对比维度 | **MediaMTX** | **ZLMediaKit** | **SRS (Simple Realtime Server)** |
| :--- | :--- | :--- | :--- |
| **开发语言** | Go (单二进制无外部依赖) | C++ (高性能) | C++ (轻量模块化) |
| **开箱易用性** | ⭐️⭐️⭐️⭐️⭐️ (极简配置，开箱即用) | ⭐️⭐️⭐️⭐️ (功能极全，配置项较多) | ⭐️⭐️⭐️⭐️ (文档丰富，上手快) |
| **边缘计算/嵌入式** | ⭐️⭐️⭐️⭐️⭐️ (资源底噪极小，极佳) | ⭐️⭐️⭐️⭐️ (需编译环境依赖) | ⭐️⭐️⭐️⭐️ (支持 Docker/ARM) |
| **核心优势协议** | RTSP、WebRTC (WHEP/WHIP)、SRT、RIST | GB28181、RTSP、RTMP、WebRTC、HLS | RTMP、WebRTC、SRT、HLS、HTTP-FLV |
| **国标 GB28181** | 需配合外部 SIP 模块 | 原生深度支持 GB28181 信令与流 | 配合外部 SIP 插件 |
| **适用主场景** | 工业物联网、IoT 边缘网关、AI 视频流中继、轻量级私有化部署 | 国内安防监控、GB28181 大规模视频汇聚平台 | 互联网大规模直播、互动课堂、CDN 边缘回源 |

---

## 🔌 端口与协议映射清单

| 端口 | 协议 | 传输层 | 说明 |
| :--- | :--- | :--- | :--- |
| `8554` | RTSP | TCP / UDP | RTSP 推流与拉流主端口（配置已优先强制 TCP） |
| `1935` | RTMP | TCP | RTMP / RTMPS 推流与拉流端口 (OBS / 经典直播) |
| `8888` | HLS | HTTP / TCP | HLS 切片流播放端点 (`/stream/index.m3u8`) |
| `8889` | WebRTC | HTTP / TCP | WebRTC WHEP (拉流播放) / WHIP (推流发布) 端点 |
| `8189` | WebRTC | UDP | WebRTC ICE Candidate 媒体传输端口 |
| `8890` | SRT | UDP | SRT (Secure Reliable Transport) 低延迟安全传输 |
| `8892` | RIST | TCP / UDP | RIST 广播级可靠互联网流传输 |
| `8893` | RIST | UDP | RIST 控制信令通道 |

---

## 🛠️ 启动与管理

### 启动服务

```bash
docker compose up -d mediamtx
```

### 查看运行日志

```bash
docker compose logs -f mediamtx
```

---

## 🎬 常用推流与播放测试示例

以流名称 `mystream` 为例：

### 1. RTSP 推流与拉流 (FFmpeg / VLC)

- **推流**：

  ```bash
  ffmpeg -re -stream_loop -1 -i input.mp4 -c copy -f rtsp rtsp://localhost:8554/mystream
  ```

- **拉流播放**：

  ```bash
  vlc rtsp://localhost:8554/mystream
  ```

### 2. RTMP 推流 (OBS Studio)

- **服务器地址**：`rtmp://localhost:1935`
- **串流密钥**：`mystream`

### 3. WebRTC / HLS 网页播放

- **HLS 网页播放**：`http://localhost:8888/mystream`
- **WebRTC WHEP 播放**：`http://localhost:8889/mystream`
