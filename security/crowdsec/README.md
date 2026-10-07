# CrowdSec 协同防御与行为入侵检测中枢

[CrowdSec](https://github.com/crowdsecurity/crowdsec) 是一款现代化的开源协同防御中枢与入侵防御系统（IPS）。它采用轻量级 Go 语言开发，通过读取反向代理（Caddy / Traefik）、SSH 或系统日志，利用声明式 YAML 场景引擎进行行为模式识别，并联动边缘网关阻断器（Bouncer）实现威胁秒级防御与社区威胁情报协同。

---

## 🎯 核心定位与防护矩阵

在微服务与全栈开发架构中，CrowdSec 与应用内 WAF 形成梯次纵深防御：

| 防护层级 | **Coraza WAF (进程内 / L7)** | **CrowdSec (行为分析与网络封禁中枢)** |
| :--- | :--- | :--- |
| **工作位置** | Caddy 网关内部（进程内直接处理 HTTP 报文） | 独立轻量分析容器（异步读取日志 / AppSec 请求分析） |
| **主要防范** | OWASP Top 10（SQL 注入、XSS、RCE、命令注入） | 恶意爬虫爆破、暴力破解、横向移动扫描、分布式撞库、已知威胁 IP |
| **响应时延** | 毫秒级同步请求检查 | **异步日志分析（网关零延迟）** + 秒级动态阻断下发 |
| **情报联动** | 单机静态规则（OWASP CRS 规则集） | **全球分布式信誉库**（数十万节点互助共享恶意 IP 黑名单） |

---

## 🏛️ 整体架构与数据流

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   外部客户端 / 攻击流量                                │
└───────────────────────────────┬───────────────────────────────┬────────────────────────┘
                                │                               │
                                ▼ (Port 80/443)                 ▼ (Port 80/443)
┌──────────────────────────────────────────────┐ ┌───────────────────────────────────────┐
│               Caddy 安全网关                 │ │               Traefik 网关            │
├──────────────────────────────────────────────┤ ├───────────────────────────────────────┤
│ • Layer 1: Fast Path 极速卸载 (404/Abort)    │ │ • Traefik CrowdSec Bouncer Middleware │
│ • Layer 2: Coraza WAF (OWASP CRS v4 深度过滤)│ │ • AppSec WAF 流量镜像 (Port 7422)     │
│ • Layer 3: caddy-crowdsec-bouncer 动态阻断   │ │                                       │
│ • 访问日志持久化输出 (/var/log/caddy/access.log)│ │ • 访问日志持久化输出 (/var/log/traefik) │
└───────────────────────┬──────────────────────┘ └───────────────────┬───────────────────┘
                        │                                            │
                        │ 1. 只读挂载访问日志                        │ 1. 只读挂载访问日志
                        ▼                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        CrowdSec 核心中枢 (crowdsecurity/crowdsec:v1.8.1-slim)          │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • Acquis 采集层: 持续跟踪 caddy.yaml / traefik.yaml / appsec.yaml                      │
│ • Parser 解析层: 解析 HTTP 访问结构并执行 lunchbox/custom-whitelists 私网豁免           │
│ • Scenario 场景层: 命中频次阈值、CVE 探测特征、撞库行为分析                             │
│ • Storage 存储层: SQLite (已启用 USE_WAL=true 高并发读写分离)                         │
│ • Local API (LAPI): 维护全局封禁决策 (Decisions) 与 Bouncer 状态同步                   │
│ • Metrics: 开放 0.0.0.0:6060 供 Prometheus / VictoriaMetrics 采集                    │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │ 2. 异步轮询/推送 Decisions 决策
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                     阻断器联动拦截 (Bouncer Remediation)                                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • Caddy 收到下发黑名单: 命中 IP 直接返回 HTTP 403 Forbidden                             │
│ • Traefik 收到下发黑名单: 拦截异常客户端，阻断非法请求进入后端微服务                   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## ✨ 行业最佳实践调优特性

本项目内的 CrowdSec 按照工业级与开发环境最佳实践深度调优，解决了官方默认配置下的常见痛点：

### 1. 防误封白名单 (Anti-Self-Banning)

- **预置文件**：`config/parsers/s02-enrich/custom-whitelists.yaml`
- **保护范围**：全量豁免私网地址与本地回环（`127.0.0.1`、`::1`、`127.0.0.0/8`、`10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`）。
- **核心价值**：彻底避免本地高并发压力测试、前端 Vite/Webpack 热重载长连接、微服务容器内部通信被识别为异常攻击而误遭拉黑封禁。

### 2. 声明式规则装配与细粒度挂载 (Declarative Hub & Fine-grained Mounts)

- **声明式规则集合**：通过 Compose 环境变量 `COLLECTIONS` 声明式配置规则（`traefik`、`caddy`、`http-cve`、`whitelist-good-actors`、`base-http-scenarios`、`appsec-virtual-patching`、`appsec-generic-rules`），容器首次启动由官方 Entrypoint 自动装配。
- **细粒度只读挂载**：`./config/acquis.d` 与 `./config/parsers/s02-enrich/custom-whitelists.yaml` 分别以 `:ro` 只读形式精准挂载进容器，本地修改配置即刻生效，杜绝全卷覆盖带来的配置漂移与官方 Hub 规则被遮蔽问题。
- **官方原生镜像**：直接采用官方轻量级 `crowdsecurity/crowdsec:v1.8.1-slim` 镜像，免去本地维护与编译 Dockerfile 的负担。

### 3. SQLite WAL 模式高并发吞吐 (Write-Ahead Logging)

- **配置注入**：`docker-compose.yml` 声明 `USE_WAL=true`。
- **性能收益**：利用 SQLite 预写日志技术实现读写并发分离，彻底消除多网关高频日志同时写入时可能诱发的 `database is locked` 互斥死锁。

### 4. 工业级探活机制 (Healthcheck Hardening)

- **探活位置**：在 `docker-compose.yml` 中声明标准容器 `healthcheck`。
- **探活指令**：`cscli lapi status > /dev/null 2>&1 || exit 1`。
- **健康保障**：真实验证本地 Local API (LAPI) 端口监听与服务就绪状态，确保网关 Bouncer 能够稳定接入。

### 5. 全链路可观测性 (Prometheus / VictoriaMetrics)

- **无侵入指标暴露**：默认开启 `:6060/metrics`，自动注册至 `victoria-agent` 监控流水线。
- **核心监控项**：实时统计日志解析行数、场景命中速率、活跃封禁决策数、LAPI 查询响应耗时。

---

## 🔌 内部端口与通信规范

| 端口 | 协议 | 访问范围 | 用途说明 |
| :--- | :--- | :--- | :--- |
| `8080` | TCP / HTTP | `backend` 内部网络 | **Local API (LAPI)**：供 Caddy/Traefik Bouncer 认证与拉取决策 |
| `7422` | TCP / HTTP | `backend` 内部网络 | **AppSec WAF 接收端口**：接收来自反代网关的深度 HTTP 报文分析 |
| `6060` | TCP / HTTP | `backend` 内部网络 | **Prometheus Metrics**：供监控采集引擎汇总运行时指标 |

> [!NOTE]
> CrowdSec 仅加入内部 Docker `backend` 网络，无需向宿主机暴露任何外部端口，保障网络最小暴露面。

---

## 📁 目录结构说明

```text
security/crowdsec/
├── docker-compose.yml          # 服务编排 (环境变数、存储卷、资源限制、探活)
├── README.md                   # 架构说明与运维操作手册
└── config/                     # 版本受控的静态配置 (GitOps)
    ├── acquis.d/               # 日志采集目标配置
    │   ├── caddy.yaml          # 采集 /var/log/caddy/access.log (JSON 格式)
    │   ├── traefik.yaml        # 采集 /var/log/traefik/access.log
    │   └── appsec.yaml         # 开启 7422 端口接收 AppSec 报文
    └── parsers/
        └── s02-enrich/
            └── custom-whitelists.yaml # 本地开发与私网绝对白名单
```

---

## 🛠️ 常用运维命令手册 (CLI Cheatsheet)

所有运维操作均可在宿主机通过 `docker compose exec crowdsec cscli` 执行：

### 1. 决策与封禁管理 (Decisions)

```bash
# 查看当前生效的封禁列表 (查看被封禁的恶意 IP)
docker compose exec crowdsec cscli decisions list

# 手动添加封禁 (示例: 封禁某个 IP 4 小时)
docker compose exec crowdsec cscli decisions add --ip 198.51.100.23 --duration 4h --reason "Manual intervention"

# 手动添加指定 IP 段封禁
docker compose exec crowdsec cscli decisions add --range 198.51.100.0/24 --duration 24h --reason "Spam subnet"

# 解除特定 IP 封禁
docker compose exec crowdsec cscli decisions delete --ip 198.51.100.23

# 清空所有封禁决策
docker compose exec crowdsec cscli decisions delete --all
```

### 2. 警报与告警事件 (Alerts)

```bash
# 查看近期触发的攻击警报
docker compose exec crowdsec cscli alerts list

# 查看特定警报详情 (ID 参考上一条命令输出)
docker compose exec crowdsec cscli alerts inspect <ALERT_ID>
```

### 3. 解析器与采集器状态 (Metrics & Parsers)

```bash
# 查看实时分析统计 (日志读取条数、解析成功率、触发拦截数)
docker compose exec crowdsec cscli metrics

# 检查当前启用的解析器列表 (确认 custom-whitelists 是否已生效)
docker compose exec crowdsec cscli parsers list

# 检查当前启用的防御场景 (Scenarios)
docker compose exec crowdsec cscli scenarios list
```

### 4. 阻断器网关管理 (Bouncers)

```bash
# 查看已注册接入的 Bouncer 列表及其最后心跳时间
docker compose exec crowdsec cscli bouncers list

# 手动新增一个 Bouncer (若未通过环境变量声明)
docker compose exec crowdsec cscli bouncers add custom-bouncer
```

### 5. 连接官方云端控制台 (CrowdSec Console - 可选)

CrowdSec 官方提供了免费的 SaaS 可视化控制台 [app.crowdsec.net](https://app.crowdsec.net/)，可在一个 Web 界面中集中查看所有节点的攻击态势与封禁列表：

```bash
# 获取注册凭证 (在控制台获取 Enroll Key) 后执行绑定：
docker compose exec crowdsec cscli console enroll <ENROLL_KEY>

# 重启容器使控制台连接生效
docker compose restart crowdsec
```
