# Neko (n.eko 自建云端虚拟浏览器与多人协同桌面)

本项目基于开源的自建云端虚拟桌面与远程浏览器 [n.eko](https://github.com/m1k1o/neko)（由 Go + WebRTC + Vue 开发），为开发环境提供安全沙箱隔离的云端浏览器、低延迟多人屏幕共享及实时协同操作工作台。

---

## 🌟 核心特性与优势

- **多浏览器生态支持**：默认集成 **Firefox** 镜像，亦可一键切换为 **Chromium**、**Google Chrome**、**Brave**、**Tor Browser** 等任意主流浏览器引擎。
- **超低延迟 WebRTC 流式推流**：基于 WebRTC 原生音视频实时同步传输，响应敏捷，支持高帧率流畅浏览与高清视频播放。
- **多人协同与实时互动**：
  - 支持多用户同时连入同一个虚拟浏览器会话，实时观摩操作。
  - 支持申请/移交鼠标键盘控制权、双向剪贴板同步及文本聊天。
  - 提供专属 Admin 管理员面板，支持静音、踢人、锁定控制等权限管理。
- **网络优化 (WebRTC MUX)**：默认启用 **UDPMUX**（UDP 多路复用），单个 UDP 端口（`52000/udp`）即可承载全部协同音视频流，告别传统暴露上百个临时端口的复杂网络环境。
- **数据持久化与下载提取**：
  - 浏览器配置文件独立持久化，会话、历史记录、书签与插件重启不丢失。
  - 下载目录映射到宿主机，云端下载的文件可直接在本地磁盘访问。

---

## 🏗️ 端口与持久化规范

### 1. 服务端口

| 协议 / 服务 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **HTTP Web / Signaling** | `8080` | `8050:8080` | Web 界面、REST API 及 WebSocket 信令接口（可通过 Caddy 反代） |
| **WebRTC UDPMUX** | `52000/udp` | `52000:52000/udp` | WebRTC 音视频媒体流单端口多路复用传输 |

### 2. 持久化数据路径

数据持久化遵从项目 `AGENTS.md` 规范，统一挂载至宿主机 `${DATA_PATH}neko`：

| 宿主机路径 | 容器内挂载路径 | 说明 |
| :--- | :--- | :--- |
| `${DATA_PATH}neko/profile` | `/home/neko/.mozilla/firefox/profile.default` | 存放 Firefox 书签、插件、历史记录与用户首选项 |
| `${DATA_PATH}neko/downloads` | `/home/neko/Downloads` | 浏览器文件下载输出目录，宿主机可直接读取 |

---

## ⚙️ 关键环境与配置参数

| 环境变量 | 默认值 | 作用说明 |
| :--- | :--- | :--- |
| `NEKO_WEBRTC_UDPMUX` | `52000` | 启用 WebRTC UDP 单端口复用（极简网络模式） |
| `NEKO_DESKTOP_SCREEN` | `1920x1080@30` | 虚拟桌面分辨率与刷新率（如 `1280x720@30`, `2560x1440@60`） |
| `NEKO_MEMBER_MULTIUSER_USER_PASSWORD` | `neko` | 访客/普通协作者访问口令 |
| `NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD` | `admin` | 管理员访问口令（拥有最高房间控制权） |
| `NEKO_WEBRTC_NAT1TO1` | `${NEKO_NAT1TO1:-127.0.0.1}` | 客户端连入 WebRTC 所需的宿主机真实 IP 地址 |

> [!NOTE]
> **关于 `NEKO_WEBRTC_NAT1TO1`**：
>
> - **本地开发**：设为 `127.0.0.1` 即可正常连入。
> - **局域网/公网部署**：必须在根目录 `.env` 中设置 `NEKO_NAT1TO1=<宿主机局域网IP或公网IP>`，否则客户端无法完成 WebRTC ICE 候选对协商建立音视频通道。

---

## 🔄 切换不同浏览器变体

如需将虚拟浏览器从 Firefox 切换为其他浏览器，仅需在 `docker-compose.yml` 中修改 `image` 标签：

```yaml
# Chromium:
image: ghcr.io/m1k1o/neko/chromium:3.1

# Google Chrome:
image: ghcr.io/m1k1o/neko/google-chrome:3.1

# Brave 隐私浏览器:
image: ghcr.io/m1k1o/neko/brave:3.1
```

*(注意：若切换为 Chromium 内核浏览器，profile 挂载路径可相应调整为 `/home/neko/.config/chromium/Default`)*

---

## 🚀 快速启动

### 1. 注册并启用模块编排

在 `apps/docker-compose.yml` 中取消注释：

```yaml
include:
  # ...
  - neko/docker-compose.yml
```

并在根目录 `docker-compose.yml` 中确认引入 `apps/docker-compose.yml`。

### 2. 启动服务

```bash
docker compose up -d neko
```

访问 `http://localhost:8050` 即可开始使用虚拟浏览器。

---

## 🌐 Caddy 反向代理接入

如需通过子域名接入（例如 `https://neko.{$SITE_ADDRESS}`），可在 `gateways/caddy/Caddyfile` 中追加：

```caddyfile
# 接入 Neko 虚拟浏览器
import proxy-app neko.{$SITE_ADDRESS} neko:8080
```
