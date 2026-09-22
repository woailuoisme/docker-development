# 基础设施与通用监控探针集群 (Exporters)

本目录聚合了系统层、容器层、缓存层与数据库层的专用 Prometheus Exporter，负责将各组件的底层运行状态转化为标准 Prometheus 格式指标，供指标时序数据库（VictoriaMetrics）周期性抓取。

---

## 📌 组件架构与功能概述

集群当前启用 3 个探针容器（cAdvisor 暂停启用），通过 `docker-compose.yml` 的 `include:` 机制统一编排：

| 探针名称 | 容器名称 | 内部端口 | 监控对象 | 核心采集指标 |
| :--- | :--- | :--- | :--- | :--- |
| **Node Exporter** | `node-exporter` | `9100` | 宿主机硬件与 OS | CPU 使用率、物理内存开销、磁盘 I/O 与容量、网络吞吐、系统负载 |
| **cAdvisor** | `cadvisor` | `8080` | Docker 容器运行时 | 容器级 CPU 节流与开销、内存工作集/限制、容器网络 I/O（暂停启用） |
| **Valkey Exporter** | `valkey-exporter` | `9121` | Valkey / Redis 缓存 | 命中率、连接数、内存碎片率、命令吞吐 (QPS)、慢查询统计 |
| **Postgres Exporter**| `postgres-exporter` | `9187` | PostgreSQL 数据库 | 活跃连接数、事务提交与回滚率、锁等待、死锁计数、缓冲区命中率 |

---

## 🏗️ 数据流拓扑

```mermaid
flowchart LR
    Host[宿主机 OS] -->|/proc, /sys| NodeExp[Node Exporter :9100]
    Docker[Docker Daemon] -->|/var/run/docker.sock| CAdv[cAdvisor :8080]
    Valkey[(Valkey :6379)] -->|REDIS_ADDR| ValkeyExp[Valkey Exporter :9121]
    PG[(PostgreSQL :5432)] -->|DATA_SOURCE_NAME| PGExp[Postgres Exporter :9187]

    NodeExp -->|HTTP GET /metrics| VM[VictoriaMetrics :8428]
    CAdv -->|HTTP GET /metrics| VM
    ValkeyExp -->|HTTP GET /metrics| VM
    PGExp -->|HTTP GET /metrics| VM

    VM -->|PromQL 查询| Grafana[Grafana 统一看板 :13000]
```

---

## ⚙️ 各组件详细配置说明

### 1. Node Exporter (`node-exporter/`)

- **镜像**：`prom/node-exporter:v1.12.1`
- **挂载点**：
  - `/proc:/host/proc:ro`
  - `/sys:/host/sys:ro`
  - `/:/rootfs:ro`
- **启动参数优化**：
  - `--path.procfs=/host/proc`
  - `--path.rootfs=/rootfs`
  - `--path.sysfs=/host/sys`
  - `--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)`：排除只读虚拟文件系统，大幅降低时序基数。
- **资源限制**：CPU `0.2` 核，内存 `64M`。

### 2. cAdvisor (`cadvisor/`) — 暂停启用

> 编排入口已注释（`exporters/docker-compose.yml`、`observability/docker-compose.yml`），vmagent 抓取任务同步停用。
> 恢复时需三处一并取消注释，否则 `container_*` 指标缺失会导致 `ContainerHighMemoryUsage` 规则永久沉默。

- **镜像**：`ghcr.io/google/cadvisor:v0.60.5`
- **特权模式**：`privileged: true`（确保安全读取 cgroups v1/v2 统计）。
- **挂载点**：
  - `/var/run:/var/run:ro`
  - `/var/lib/docker/:/var/lib/docker:ro`
  - `/dev/disk/:/dev/disk:ro`
- **精简优化参数**：
  - `--docker_only=true`：仅采集 Docker 容器，忽略非容器 cgroup。
  - `--housekeeping_interval=15s`：采样步长提升至 15s，降低后台扫描 CPU 开销。
  - `--disable_metrics=disk,diskIO,tcp,udp,percpu,sched,process,hugetlb,referenced_memory,cpu_topology,resctrl,accelerator`：彻底停用大页、内存引用扫描、进程树、单核裂变与磁盘冗余指标。
  - `--whitelisted_container_labels=com.docker.compose.project,com.docker.compose.service`：白名单截断无用 Docker labels，阻断时序基数膨胀。
- **资源限制**：CPU `0.3` 核，内存 `96M`。

### 3. Valkey Exporter (`valkey-exporter/`)

- **镜像**：`oliver006/redis_exporter:v1.90.0`
- **环境变量**：
  - `REDIS_ADDR=redis://valkey:6379`
  - `REDIS_PASSWORD=${REDIS_PASSWORD:-}`
- **资源限制**：CPU `0.2` 核，内存 `64M`。

### 4. Postgres Exporter (`postgres-exporter/`)

- **镜像**：`prometheuscommunity/postgres-exporter:v0.20.1`
- **环境变量**：
  - `DATA_SOURCE_NAME=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/postgres?sslmode=disable`
- **资源限制**：CPU `0.2` 核，内存 `64M`。

---

## 🚀 启动与运维指令

### 1. 单独启动或重启探针服务

在项目根目录下执行：

```bash
# 启动全部 Exporters
docker compose up -d node-exporter valkey-exporter postgres-exporter

# 查看探针运行状态
docker compose ps node-exporter valkey-exporter postgres-exporter

# 重启指定探针
docker compose restart valkey-exporter
```

### 2. 验证指标采集接口

探针加入内部网络 `backend`，可通过同网络容器或端口转发快速检查指标输出：

```bash
# 验证 Node Exporter 指标
docker compose exec -T victoria-metrics wget -q -O - http://node-exporter:9100/metrics | head -n 20

# 验证 cAdvisor 容器监控指标（需先恢复 cadvisor 编排，当前暂停启用）
# docker compose exec -T victoria-metrics wget -q -O - http://cadvisor:8080/metrics | grep container_cpu_usage_seconds_total | head -n 10

# 验证 Valkey Exporter 指标
docker compose exec -T victoria-metrics wget -q -O - http://valkey-exporter:9121/metrics | grep valkey_up

# 验证 Postgres Exporter 指标
docker compose exec -T victoria-metrics wget -q -O - http://postgres-exporter:9187/metrics | grep pg_up
```

---

## 🔍 故障排查 (Troubleshooting)

1. **cAdvisor 内存持续泄露**：
   - 确认启动参数中开启了 `--docker_only=true` 并使用 `--disable_metrics` 禁用了 `percpu` 和 `process` 级指标。
2. **Postgres Exporter 报连接认证错误 (`pg_up == 0`)**：
   - 检查 `.env` 文件中的 `POSTGRES_PASSWORD` 是否与 `database/postgres-18/` 容器初始密码匹配。
3. **Valkey Exporter 无法连接**：
   - 检查 `REDIS_PASSWORD` 是否已配置，确认网络是否正常加入 `backend`。
