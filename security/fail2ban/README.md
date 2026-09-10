# Fail2ban 容器化安全防护与恶意 IP 封禁网关

本模块基于官方与社区广泛信赖的 [`crazymax/fail2ban`](https://github.com/crazy-max/docker-fail2ban) 镜像构建，作为本项目的一套**可选安全隔离容器服务**。

Fail2ban 通过自动化巡检解析网关与系统日志，针对恶意扫描探测、凭据暴力破解等高危行为，自动调用宿主机网络防火墙（`iptables` / `nftables`）下发动态拦截规则，实现毫秒级边界防护。

---

## 1. 核心架构与 Docker 拦截原理

### 1.1 为什么不能用传统的 INPUT 链拦截 Docker 流量？

传统 Fail2ban 默认将规则插入 Linux 系统的 `INPUT` 链。但在 Docker 环境中：

1. **Docker 端口发布机制**：当容器通过 `ports: - "80:80"` 暴露端口时，宿主机内核使用 `iptables` 的 `PREROUTING` 链进行 NAT/DNAT 地址转换。
2. **流量转发路径**：经过 NAT 后的流量直接流入 `FORWARD` 链，而**完全不经过 `INPUT` 链**。
3. **绕过风险**：如果 Fail2ban 仅封禁 `INPUT` 链，外部针对 Caddy、Nginx 或 Web 应用容器的恶意流量将畅通无阻。

### 1.2 本方案的双链分离防御机制

为了彻底解决这一问题，本项目采用精确的**双链分层拦截架构**：

- **Web 网关容器防御 (`caddy.local` / `nginx.local`)**：
  - Action 显式指定 `chain="DOCKER-USER"`。
  - Docker 官方专门预留了 `DOCKER-USER` 过滤链，它在所有 Docker 自带的转发过滤之前被评估。只要在 `DOCKER-USER` 链下发 `DROP` 规则，就能精准阻断恶意源 IP 对任意容器端口的访问。
- **宿主机原生服务防御 (`sshd.local`)**：
  - Action 保持指定 `chain="INPUT"`。
  - 针对直接监听在宿主机系统端口上的原生 SSH 等服务，在宿主机入口直接拦截，实现对 VPS 主机本身的加固。

```text
外部访问流量
     │
     ▼
[PREROUTING (NAT)]
     │
     ├───────────► 宿主机本地进程 (例如 SSH 端口 22) ──► [INPUT 链] ◄── [sshd Jail 封禁点]
     │
     └───────────► 目标为容器端口 (例如 80/443) ──► [FORWARD 链]
                                                        │
                                                        ▼
                                                  [DOCKER-USER 链] ◄── [caddy Jail 封禁点]
                                                        │
                                                        ▼
                                                  [Web 应用容器]
```

---

## 2. 目录结构与配置规范

```text
security/fail2ban/
├── docker-compose.yml           # Fail2ban 容器服务编排定义 (host 网络与 NET_ADMIN 特权)
├── manage.sh                    # 统一运维管理脚本 (status / banned / ban / unban)
├── README.md                    # 本模块技术架构与运维手册
└── config/                      # 声明式规则挂载目录
    ├── jail.d/                  # Jails 规则定义目录
    │   ├── 00-default.local     # 全局默认参数 (bantime, findtime, maxretry 与白名单)
    │   ├── caddy.local          # Caddy 网关安全防御 Jail (拦截 DOCKER-USER 链)
    │   ├── nginx.local          # Nginx 网关安全防御 Jail (备选网关，拦截 DOCKER-USER 链)
    │   └── sshd.local           # 宿主机 SSH 防御 Jail (拦截 INPUT 链)
    ├── filter.d/                # 自定义日志过滤器目录
    │   └── caddy-scanner.conf   # Caddy JSON 访问日志嗅探与恶意路径匹配规则
    └── action.d/                # 自定义防火墙执行动作目录 (按需扩展)
```

---

## 3. 持久化与挂载路径说明

遵循项目全局 `AGENTS.md` 规范：

| 挂载类型 | 宿主机路径 | 容器内目标路径 | 读写权限 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **数据持久化** | `${DATA_PATH}fail2ban/db` | `/data/db` | `rw` | 持久化 `fail2ban.sqlite3`，确保重启不丢失封禁记录 |
| **规则配置** | `${CONFIG_PATH}security/fail2ban/config/jail.d` | `/data/jail.d` | `ro` | 声明式 Jail 规则配置 |
| **过滤规则** | `${CONFIG_PATH}security/fail2ban/config/filter.d` | `/data/filter.d` | `ro` | 自定义正则表达式过滤配置 |
| **动作规则** | `${CONFIG_PATH}security/fail2ban/config/action.d` | `/data/action.d` | `ro` | 自定义防火墙处理动作 |
| **网关日志** | `${LOG_PATH}caddy` | `/var/log/caddy` | `ro` | 实时采集 Caddy 访问日志 `access.log` |
| **网关日志** | `${LOG_PATH}nginx` | `/var/log/nginx` | `ro` | 实时采集 Nginx 访问日志（备选网关） |
| **系统日志** | `/var/log` | `/var/log/host` | `ro` | 挂载宿主机 `/var/log/auth.log` 或 `/var/log/secure` |

---

## 4. 快速上手与常用命令

### 4.1 启动服务

Fail2ban 在 `security/docker-compose.yml` 中默认处于可选注释状态。启用步骤：

1. 在 `docker-compose.yml` 的第 11 节取消 `- security/docker-compose.yml` 的注释，并在 `security/docker-compose.yml` 中取消 `- fail2ban/docker-compose.yml` 的注释。
2. 执行以下命令启动服务：

```bash
docker compose up -d fail2ban
```

### 4.2 运维与封禁管理 (通过 justfile 或 manage.sh)

模块内置便捷管理脚本，已集成进根目录 `justfile`：

```bash
# 1. 查看 Fail2ban 全局运行状态及已启用的 Jail 列表
just f2b-status
# 或执行: ./security/fail2ban/manage.sh status

# 2. 查看特定 Jail 的详细统计与被封禁 IP (例如 caddy)
./security/fail2ban/manage.sh status caddy

# 3. 一键汇总列出所有 Jail 当前封禁的所有 IP 清单
just f2b-banned
# 或执行: ./security/fail2ban/manage.sh banned

# 4. 手动解封误封的 IP 地址
just f2b-unban 198.51.100.2 caddy
# 或执行: ./security/fail2ban/manage.sh unban caddy 198.51.100.2
# 或全局解封: ./security/fail2ban/manage.sh unban-all 198.51.100.2

# 5. 手动封禁恶意 IP
./security/fail2ban/manage.sh ban caddy 198.51.100.2

# 6. 修改配置后平滑重新加载
./security/fail2ban/manage.sh reload

# 7. 实时追踪 Fail2ban 容器运行日志
./security/fail2ban/manage.sh logs 100
```

---

## 5. 内网白名单保护机制

为杜绝本地联调、容器间微服务调用、Caddy 健康检查或开发工作站被误封，`00-default.local` 默认启用了私网豁免网段：

```ini
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
```

如需增加固定运维堡垒机 IP 或 Office 外网静态出口，可在 `security/fail2ban/config/jail.d/00-default.local` 中的 `ignoreip` 结尾追加即可（空格分隔）。

---

## 6. 常见问题 (FAQ)

### Q1: 在 macOS (Docker Desktop) 上运行是否生效？

- **答**：macOS 上的 Docker 运行于轻量级 Linux 虚拟机内部。`fail2ban` 在 macOS 下虽然可以正常启动并读取日志，但它下发的 `iptables` 规则仅生效在虚拟机内部网络栈中，**无法拦截 macOS 宿主机物理网卡上的直接访问**。
- **最佳实践**：macOS 本地开发建议以调试规则为主；真实防御建议部署于 Linux 服务器（VPS / 物理机）。

### Q2: 为什么有了 CrowdSec 还需要 Fail2ban？

- **CrowdSec**：现代协同防御引擎，主打威胁情报共享、基于 LAPI 架构以及应用层反代插件（Caddy AppSec / Bouncer），拦截发生在应用上下文。
- **Fail2ban**：经典轻量级防火墙防护，基于内核 `iptables` 在网络层直接丢弃数据包（Zero Overhead），不消耗应用网关与反代资源。
- 两者可独立选用或组合互补。
