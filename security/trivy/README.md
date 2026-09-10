# Aqua Security Trivy 全栈容器漏洞与安全合规扫描引擎

[Trivy](https://github.com/aquasecurity/trivy) 是云原生领域广泛使用的开源全能安全扫描器。它支持对**容器镜像 (Container Images)**、**源码文件系统 (Filesystems)**、**基础设施即代码配置 (IaC / Dockerfile / Compose)**、**硬编码密钥与敏感凭证 (Secrets)** 以及 **软件物料清单 (SBOM)** 进行极速、精准的安全漏洞与合规性检测。

---

## 🎯 核心定位与检测矩阵

在全栈开发与容器基础设施中，Trivy 构筑了静态安全与供应链合规基石：

| 扫描维度 | **检测目标** | **主要防范与发现能力** | **典型应用场景** |
| :--- | :--- | :--- | :--- |
| **容器镜像 (Image)** | 基础镜像操作系统包与应用依赖层 | 已知 CVE 漏洞、过时基础镜像包、未修补安全风险 | 本地镜像构建校验、Zot 仓库入库扫描、CI/CD 交付门禁 |
| **源码文件 (FS)** | 项目依赖清单（Composer、NPM、Go Module、Pip 等） | 第三方开源库漏洞、恶意引入依赖包、高危组件拦截 | 开发阶段依赖体检、版本升级安全评估 |
| **IaC 配置 (Config)** | Dockerfile、Compose YAML、K8s Manifests | 特权提权、Root 运行、挂载危险目录、弱配置规范 | 基础设施配置静态审查、安全准入基准校验 |
| **敏感凭据 (Secret)** | 源代码、配置文件与容器环境变量 | 意外泄露的 API Token、私钥、数据库密码、Cloud 凭证 | 代码提交防泄露阻断、镜像构建深度剥离检测 |
| **物料清单 (SBOM)** | CycloneDX、SPDX 格式软件物料清单 | 许可证法律合规、依赖拓扑分析、软硬件资产盘点 | 商业化合规审计、供应链安全审查 |

---

## 🏛️ 整体架构与数据流

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                开发者 / CI/CD / 运维终端                                │
└───────────────────────────────┬───────────────────────────────┬────────────────────────┘
                                │                               │
                                │ 1. 随需扫描 (CLI/Justfile)    │ 2. 客户端或 API 对接
                                ▼                               ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        Aqua Security Trivy 统一引擎 (Container)                        │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • Client/Server Engine: 监听 0.0.0.0:4954，支持 HTTP API 与 Trivy Client 通信         │
│ • Local Cache & DB: 持久化挂载 ${DATA_PATH}trivy/cache，避免重复拉取漏洞库             │
│ • Scan Handlers:                                                                       │
│     ├── vuln (CVE 漏洞库匹配)                                                          │
│     ├── misconfig (Dockerfile / Docker Compose 安全基线检查)                           │
│     ├── secret (规则引擎探查硬编码密钥)                                                │
│     └── license (开源许可证兼容性分析)                                                 │
│ • 报告输出格式: table / json / sarif / cyclonedx / template (HTML)                     │
└───────────────────────────────┬───────────────────────────────┬────────────────────────┘
                                │                               │
                                │ 3. 只读读取套接字与源码       │ 4. 报告持久化
                                ▼                               ▼
┌──────────────────────────────────────────────┐ ┌───────────────────────────────────────┐
│              宿主环境与代码目录              │ │         报告导出与下游系统          │
├──────────────────────────────────────────────┤ ├───────────────────────────────────────┤
│ • /var/run/docker.sock: 探查宿主机本地镜像   │ │ • ${DATA_PATH}trivy/reports           │
│ • ${CONFIG_PATH}: 静态审计项目 IaC 配置      │ │ • Zot 私有镜像仓库漏洞元数据集成    │
│ • ${APP_CODE_PATH}: 审计业务源码与组件锁文件 │ │ • Gitea / Woodpecker CI 门禁中断      │
└──────────────────────────────────────────────┘ └───────────────────────────────────────┘
```

---

## 🚀 两种运行模式

本项目为 Trivy 提供了**常驻服务模式 (Server Mode)** 与 **随需独立扫描模式 (CLI Mode)**：

### 1. 常驻服务端模式 (Server Mode)

适合与私有镜像仓库（Zot Registry）、自动化 CI/CD 流水线或监控平台集成：

```bash
# 启动常驻 Trivy Server 服务端 (默认端口 4954)
docker compose up -d trivy

# 查看服务端日志与离线漏洞库初始化状态
docker compose logs -f trivy

# 验证服务端运行状态
./security/trivy/scan.sh server-status
```

### 2. 随需独立扫描模式 (CLI Mode)

无需在宿主机安装任何依赖，通过 `justfile` 或 `scan.sh` 直接以临时容器运行扫描，与服务端共享本地漏洞库缓存：

```bash
# 扫描指定本地或远程 Docker 镜像
just scan-image caddy:latest

# 扫描当前项目的 Dockerfile 与 Compose 配置安全规范
just scan-iac

# 扫描项目应用目录与第三方扩展依赖包
just scan-app
```

---

## 💻 实用命令参考

### 1. 扫描 Docker 容器镜像

```bash
# 扫描基础镜像并展示漏洞摘要表格
./security/trivy/scan.sh image alpine:latest

# 仅显示严重程度为 HIGH 和 CRITICAL 的高危漏洞
./security/trivy/scan.sh image php:8.3-fpm-alpine --severity HIGH,CRITICAL

# 过滤掉官方尚未发布补丁的漏洞 (专注可修复项)
./security/trivy/scan.sh image redis:alpine --ignore-unfixed
```

### 2. 审计 IaC 基础设施与 Dockerfile 配置

检查 Dockerfile 或 Compose 是否存在以 Root 运行、未设置资源限额、挂载危险目录等配置陷阱：

```bash
# 静态检测当前整个项目的配置文件
./security/trivy/scan.sh config .

# 单独检测指定 Dockerfile
./security/trivy/scan.sh config gateways/caddy/Dockerfile
```

### 3. 扫描源码目录与组件依赖

支持深度解析 `composer.lock`、`package-lock.json`、`pnpm-lock.yaml`、`go.mod` 等：

```bash
# 扫描指定代码仓库或项目根目录
./security/trivy/scan.sh fs /var/www/lunchbox
```

### 4. 生成与导出 SBOM 软件物料清单

```bash
# 生成 CycloneDX 格式标准 SBOM 文件
./security/trivy/scan.sh sbom caddy:latest ./data/trivy/reports/caddy-sbom.json
```

### 5. 导出 HTML 可视化报告

```bash
# 导出美观的 HTML 网页版安全报告
docker run --rm -v "${DATA_PATH:-./data/}trivy/cache:/root/.cache/trivy" \
  -v "/var/run/docker.sock:/var/run/docker.sock:ro" \
  -v "${DATA_PATH:-./data/}trivy/reports:/root/reports" \
  aquasec/trivy:latest image --format template --template "@contrib/html.tpl" \
  -o /root/reports/caddy-report.html caddy:latest
```

---

## ⚙️ 配置文件与误报治理

### 1. 全局配置文件 `trivy.yaml`

所有默认行为（漏洞库镜像源、扫描器类型、默认跳过目录等）均在 `security/trivy/trivy.yaml` 中声明式定义，容器启动时自动挂载至 `/root/trivy.yaml`。

### 2. 白名单与豁免规则 `.trivyignore`

对于经安全团队评估后无需处理或暂无攻击面的已知 CVE，可在 `security/trivy/.trivyignore` 中添加规则进行过滤：

```text
# 忽略官方已知但无法利用的动态链接库漏洞（支持到期时间）
CVE-2023-12345 exp:2026-12-31

# 忽略开发测试用辅助镜像的特定告警
CVE-2024-54321
```

---

## 🔗 与私有镜像仓库 (Zot Registry) 对接

本项目中的私有镜像仓库服务（`devtools/zot`）支持直接与 Trivy 对接实现推送后镜像自动扫描。

在 `devtools/zot/zot-config.json` 的 `extensions` 节点可增加 Trivy 远程扫描配置：

```json
"extensions": {
  "sync": {
    "enable": false
  },
  "search": {
    "enable": true
  }
}
```

配合在 CI/CD 流水线（Woodpecker 或 Gitea Actions）中调用 `trivy image --server http://trivy:4954 registry.{$SITE_ADDRESS}/repo:tag`，即可在发布镜像前实施自动化安全门禁阻断。
