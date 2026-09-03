# SRS (Simple Realtime Server) 6.x 高性能实时流媒体服务器

[SRS (Simple Realtime Server)](https://github.com/ossrs/srs) 是全球顶尖且应用最广泛的开源工业级音视频服务器，专注于高并发、低延迟流媒体集群编排。原生支持 **RTMP、HTTP-FLV、HLS、WebRTC、SRT、GB28181** 多协议高效互转与毫秒级低延迟分发。

---

## 🎯 SRS、MediaMTX 与 LiveKit 技术选型对比

| 维度 | **SRS (工业级流媒体引擎)** | **MediaMTX (轻量全协议中枢)** | **LiveKit (WebRTC SFU 平台)** |
| :--- | :--- | :--- | :--- |
| **核心定位** | **高并发大规模推拉流集群** | **轻量易维护的多协议路由网关** | **多人实时互动音视频与 AI SFU** |
| **典型场景** | 直播平台、赛事直播、在线教育、安防监控转码分发 | 监控摄像头 RTSP 汇聚、局域网流转码、开发调试 | 多人音视频会议、屏幕共享、Realtime 实时 AI 对话 |
| **交互模型** | 单向广播（1 推多拉） / WebRTC 极速拉流 | 单向转发（1 推多拉） | 双向/多向多方实时交互（Pub-Sub Room） |
| **延迟表现** | WebRTC: 200~500ms; FLV: 1~3s; HLS: 3~10s | WebRTC: ~500ms; HLS: 2~5s | 全球端到端 **< 100ms** |
| **协议支持** | RTMP, FLV, HLS, WebRTC, SRT, GB28181 | RTSP, RTMP, HLS, WebRTC, SRT, RIST | WebRTC (纯私有信令 + 标准 ICE/RTP) |

---

## 🏛️ 端口映射矩阵

| 宿主机端口 | 容器内端口 | 协议 | 功能说明 |
| :--- | :--- | :--- | :--- |
| `${SRS_RTMP_PORT:-1935}` | `1935` | TCP | RTMP 推流（OBS、FFmpeg）与 RTMP 播放拉流 |
| `${SRS_API_PORT:-1985}` | `1985` | TCP | HTTP API 控制接口、流状态查询与 WebRTC 信令交互 |
| `${SRS_HTTP_PORT:-8080}` | `8080` | TCP | HTTP 服务器：分发 HTTP-FLV、HLS 切片流及内置 Web 控制台 |
| `${SRS_RTC_PORT:-8000}` | `8000` | UDP | WebRTC 音视频传输（客户端必须能直连此 UDP 端口） |
| `${SRS_SRT_PORT:-10080}` | `10080` | UDP | SRT (Secure Reliable Transport) 极速低延迟推拉流传输 |

---

## 🚀 快速推流与播放实操

### 1. RTMP 推流 (通过 OBS 或 FFmpeg)

- **推流地址**: `rtmp://<服务器IP>:1935/live/livestream`
- **使用 FFmpeg 推送测试流**:

  ```bash
  ffmpeg -re -f lavfi -i testsrc=size=1280x720:rate=30 \
    -f lavfi -i sine=frequency=1000:sample_rate=44100 \
    -c:v libx264 -preset veryfast -c:a aac -f flv \
    rtmp://localhost:1935/live/livestream
  ```

### 2. 多协议拉流播放

流推送成功后，SRS 会自动完成协议转换，支持以下拉流方式：

- **WebRTC 超低延迟播放 (< 500ms)**:
  在浏览器访问 SRS 内置控制台播放器：
  `http://localhost:8080/players/rtc_player.html?api=1985&autostart=true&stream=livestream&app=live`
- **HTTP-FLV 播放 (1~3s 延迟)**:
  `http://localhost:8080/live/livestream.flv`
- **HLS (m3u8) 移动端兼容播放**:
  `http://localhost:8080/live/livestream.m3u8`
- **RTMP 传统播放**:
  `rtmp://localhost:1935/live/livestream`

---

## ⚙️ 关键配置注意事项

### 1. WebRTC `$CANDIDATE` 外网 IP 设置

WebRTC 在建立媒体连接时，服务端会向客户端声明自己的 IP 地址（ICE Candidate）。

- **本地开发**: 默认为 `127.0.0.1`。
- **局域网/跨设备测试**: 在 `.env` 中设置宿主机局域网 IP（例如 `SRS_CANDIDATE=192.168.1.100`）。
- **公网云服务器**: 设置为公网弹性 IP，并确保防火墙放行 UDP `8000`。

### 2. 与 MediaMTX 的端口协调

由于 SRS 与 MediaMTX 均提供了 RTMP (`1935`) 与 HTTP API/Web 服务，当两个服务同时启动时，可在 `.env` 中调整端口映射：

```env
SRS_RTMP_PORT=19350
SRS_API_PORT=19850
SRS_HTTP_PORT=8088
```
