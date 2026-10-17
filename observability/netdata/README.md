# Netdata (低配置服务器精简实时系统监控)

本项目基于开源的高性能单机实时系统监控工具 [Netdata](https://github.com/netdata/netdata)，针对 1 核 1G/2G 等低配置服务器（VPS / 云主机）进行了深度低开销调优，兼顾秒级实时系统监控能力与极致的系统资源节约。

---

## 🌟 核心特性与低配调优策略

- **秒级实时性能监控**：提供开箱即用的高交互性 Web 仪表板，全面覆盖 CPU、内存、磁盘 IO、网络、系统服务及 Docker 容器运行状态。
- **内存极致优化（~150MB RAM）**：
  - 默认多层降采样历史（Tier 1/2）占用较多内存，调优方案强制设为 **单层存储 (`storage tiers = 1`)**。
  - 限制 dbengine 的 **Page Cache 为 16MB**（官方默认通常为 32MB~64MB 以上），避免低配 VPS 发生 OOM。
  - 限制磁盘持久化空间为 **256MB**，防止监控时序数据无节制占用有限的磁盘空间。
- **CPU 运算与系统调用精简**：
  - **放宽采样频率**：将默认每秒抓取（`update every = 1`）调整为 **2 秒抓取 (`update every = 2`)**，降低 50% 的 CPU 唤醒与系统调用负载。
  - **彻底关闭 ML 异常检测 (`[ml] enabled = no`)**：Netdata 内置的机器学习模型持续训练与推理会产生不可忽视的 CPU/内存常驻开销，低配环境果断剔除。
  - **禁用 eBPF 与 slabinfo 插件 (`ebpf = no`, `slabinfo = no`)**：剔除内核级动态插桩编译与高开销追踪，容器无需授予特权级 `SYS_ADMIN` 能力，仅保留进程采样所需的 `SYS_PTRACE`。
  - **关闭高频访问日志 (`access log = none`)**：避免高频 Web 请求持续刷写磁盘造成 IO 抖动。
- **纯私有离线运行与隐私保护**：
  - 显式配置 `[cloud] enabled = no` 与 `DO_NOT_TRACK: 1`，彻底杜绝云端心跳、匿名遥测与外网联机开销。
- **安全接入架构**：
  - 宿主机端口严格锁定在 `127.0.0.1:19999`，外部一律通过 Caddy 网关反向代理，配合 Authelia 进行统一登录鉴权保护。

---

## 🏗️ 端口与持久化规范

### 1. 服务端口

| 协议 / 服务 | 容器内部端口 | 宿主机映射端口 | 说明 |
| :--- | :--- | :--- | :--- |
| **HTTP Web Console / API** | `19999` | `127.0.0.1:19999:19999` | Netdata 实时 Web 仪表板与监控数据 API（仅限本机回环访问） |

### 2. 持久化数据与配置路径

| 宿主机路径 | 容器内挂载路径 | 权限 / 说明 |
| :--- | :--- | :--- |
| `./config/netdata.conf` | `/etc/netdata/netdata.conf` | `ro`，Netdata 低配调优专属配置文件 |
| `${DATA_PATH}netdata/lib` | `/var/lib/netdata` | `rw`，Netdata 内部数据库与状态元数据 |
| `${DATA_PATH}netdata/cache` | `/var/cache/netdata` | `rw`，Netdata dbengine 时序数据磁盘缓存 |
| `/` | `/host/root` | `ro,rslave`，宿主机根文件系统监控 |
| `/proc` | `/host/proc` | `ro`，宿主机进程与内核指标挂载 |
| `/sys` | `/host/sys` | `ro`，宿主机硬件与系统子系统指标挂载 |
| `/etc/os-release` | `/host/etc/os-release` | `ro`，宿主机发行版信息 |
| `/etc/localtime` | `/host/etc/localtime` | `ro`，宿主机时区文件同步 |
| `/etc/passwd` | `/host/etc/passwd` | `ro`，宿主机用户解析 |
| `/etc/group` | `/host/etc/group` | `ro`，宿主机用户组解析 |
| `/var/log` | `/host/var/log` | `ro`，宿主机日志监控（可选） |
| `/var/run/docker.sock` | `/var/run/docker.sock` | `ro`，Docker 容器状态与资源监控 |
| `/run/dbus` | `/run/dbus` | `ro`，系统 D-Bus 总线通信（systemd 服务健康检测） |

---

## ⚙️ 核心配置文件 (`config/netdata.conf`)

挂载于容器内的精简调优配置如下：

```ini
[global]
    update every = 2
    access log = none
    error log = /dev/stderr
    debug log = none

[db]
    mode = dbengine
    storage tiers = 1
    dbengine page cache size MB = 16
    dbengine multihost disk space MB = 256

[ml]
    enabled = no

[cloud]
    enabled = no

[plugins]
    ebpf = no
    slabinfo = no

[web]
    bind to = 0.0.0.0:19999
    mode = static-threaded
```

---

## 🚀 启动与运维指南

### 1. 启用编排

在 `observability/docker-compose.yml` 中取消对 Netdata 的注释：

```yaml
include:
  - netdata/docker-compose.yml              # Netdata 极速低开销单机实时系统监控
```

### 2. 启动服务

```bash
# 启动 Netdata 容器
docker compose up -d netdata

# 查看启动日志与初始化状态
docker compose logs -f netdata
```

### 3. 配置网关反向代理 (Caddy)

在 `gateways/caddy/Caddyfile` 中取消或添加反代配置：

```caddyfile
import proxy-app-auth netdata.{$SITE_ADDRESS} netdata:19999
```

重载 Caddy 网关：

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

通过浏览器访问 `https://netdata.<你的域名>`，经 Authelia 认证后即可直达精简流畅的实时监控看板。

---

## 🔍 健康检查与资源验证

```bash
# 检查 Netdata 容器内部健康状态
docker inspect --format='{{json .State.Health}}' netdata

# 验证 API 连通性
curl -fsS http://127.0.0.1:19999/api/v1/info | grep -o '"version":[^,]*'

# 监控容器实际内存与 CPU 消耗（预期驻留内存在 100MB~150MB 之间）
docker stats netdata --no-stream
```
