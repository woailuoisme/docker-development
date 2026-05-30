# Centrifugo Dockerfile 与最佳实践配置设计文档

本文档详细描述了为 Centrifugo 服务引入自定义 Dockerfile 以及优化生产级配置的设计方案，旨在确保其安全性、高可用性、时区一致性，并融入本项目的 Docker Compose 服务体系中。

## 1. 目标与背景
目前项目下的 `centrifugo/` 文件夹中仅包含基本的 `config.yaml` 和 `config-dev.yaml`，而 `docker-compose.yml` 直接拉取了官方预编译镜像。为了统一容器时区（`Asia/Shanghai`）、强化运行时安全（非 root 运行）、添加内置健康检查，并对 Valkey 引擎连接池及日志系统进行生产级优化，特制定本方案。

## 2. 方案详述

### A. Dockerfile 构建设计
在 `centrifugo/Dockerfile` 中采用官方镜像进行扩展：
*   **基础镜像**：`centrifugo/centrifugo:6.8.1`（Alpine 基础）
*   **时区设定**：安装 `tzdata` 并配置 `TZ=Asia/Shanghai`。
*   **安全规范**：在 root 下准备目录并分权后，恢复为非 root 用户 `centrifugo`（UID 1001）运行，避免安全风险。
*   **健康检查**：使用 `wget` 访问自带的 `http://localhost:8000/health` 检查可用性。

### B. 配置文件优化
#### 生产配置 (`centrifugo/config.yaml`)
*   **引擎调优**：使用 Valkey (Redis 协议)，并显式配置连接池（`pool_size: 256`、`min_idle_conns: 10` 等）。
*   **安全加固**：默认禁用匿名连接（`allow_anonymous_connect_without_token: false`），强制 JWT。跨域源（Allowed Origins）设为空数组，通过环境变量动态覆盖。
*   **日志格式**：设定 `log.format: json`，以便与系统的日志聚合工具对接。

#### 开发配置 (`centrifugo/config-dev.yaml`)
*   保持使用内置 `memory` 引擎。
*   启用匿名连接和 `*` 跨域，便于本地开发调试。
*   采用 `text` 格式日志，便于开发者终端直观排错。

### C. Docker Compose 集成
修改 `centrifugo/docker-compose.yml`：
*   将 `image` 替换为 `build` 块以指向本地 `Dockerfile`。
*   通过 `CENTRIFUGO_` 前缀的环境变量传递敏感凭证（如 `CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY` 等）。
*   利用 `depends_on.valkey.condition: service_healthy` 确保启动顺序。

---

## 3. 详细代码设计

### Dockerfile (`centrifugo/Dockerfile`)
```dockerfile
# 锁定 Centrifugo 版本
ARG CENTRIFUGO_VERSION=6.8.1
FROM centrifugo/centrifugo:${CENTRIFUGO_VERSION}

# 临时切换到 root 账户配置系统环境
USER root

# 设置系统时区并安装 tzdata
ENV TZ=Asia/Shanghai
RUN apk add --no-cache tzdata && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# 创建数据与配置目录，并设置非 root 用户权限
RUN mkdir -p /centrifugo && \
    chown -R centrifugo:centrifugo /centrifugo

# 复制默认配置文件到容器中
COPY --chown=centrifugo:centrifugo config.yaml /centrifugo/config.yaml
COPY --chown=centrifugo:centrifugo config-dev.yaml /centrifugo/config-dev.yaml

# 恢复使用官方非 root 用户 centrifugo (UID 1001)
USER centrifugo

WORKDIR /centrifugo

EXPOSE 8000

# 生产级健康检查
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8000/health || exit 1
```

### 生产配置文件 (`centrifugo/config.yaml`)
```yaml
# Centrifugo v6 生产级配置
# 参考: https://centrifugal.dev/docs/server/configuration

# ============================================
# 传输协议配置
# ============================================
websocket:
  use_write_buffer_pool: true

uni_websocket:
  enabled: true

http_stream:
  enabled: true

sse:
  enabled: true

# ============================================
# 引擎配置 - 使用 Valkey (兼容 Redis 协议)
# ============================================
engine:
  type: redis
  redis:
    # 具体的连接地址将通过环境变量 CENTRIFUGO_ENGINE_REDIS_ADDRESS 动态注入
    # 生产连接池调优
    pool_size: 256
    min_idle_conns: 10
    dial_timeout: "5s"
    read_timeout: "3s"
    write_timeout: "3s"

# ============================================
# 客户端连接配置
# ============================================
client:
  # 生产环境默认禁止匿名连接，强制启用 JWT 校验
  allow_anonymous_connect_without_token: false
  
  # 跨域域名列表（允许从环境变量 CENTRIFUGO_CLIENT_ALLOWED_ORIGINS 传入 JSON 数组进行覆盖）
  allowed_origins: []

  ping_interval: 30s
  pong_timeout: 8s
  connection_limit: 10000
  user_connection_limit: 10
  queue_max_size: 1048576  # 1MB
  stale_close_delay: "10s"

# ============================================
# 管理后台与监控
# ============================================
admin:
  enabled: true
  # 密码和密钥将通过环境变量注入：
  # CENTRIFUGO_ADMIN_PASSWORD 和 CENTRIFUGO_ADMIN_SECRET

health:
  enabled: true

prometheus:
  enabled: true

# ============================================
# 日志配置
# ============================================
log:
  level: info
  format: json # 生产环境默认输出 JSON

# ============================================
# 通道命名空间配置
# ============================================
channel:
  history_meta_ttl: "720h"  # 30天
  
  namespaces:
    - name: public
      presence: true
      join_leave: true
      history_size: 100
      history_ttl: "300s"
      force_recovery: true
      allow_publish_for_subscriber: true
      allow_subscribe_for_client: true
      allow_subscribe_for_anonymous: false
      allow_publish_for_anonymous: false
    
    - name: private
      presence: true
      join_leave: true
      history_size: 100
      history_ttl: "300s"
      force_recovery: true
      allow_publish_for_subscriber: false
      allow_subscribe_for_client: false
    
    - name: user
      presence: false
      join_leave: false
      history_size: 50
      history_ttl: "300s"
      force_recovery: true
      allow_publish_for_subscriber: false
      allow_subscribe_for_client: false
    
    - name: notification
      presence: false
      join_leave: false
      history_size: 10
      history_ttl: "60s"
      force_recovery: false
      allow_publish_for_subscriber: false
      allow_subscribe_for_client: true
```

### 开发配置文件 (`centrifugo/config-dev.yaml`)
```yaml
# Centrifugo v6 开发环境配置
# 用于本地开发和测试

# ============================================
# 传输协议配置
# ============================================
websocket:
  use_write_buffer_pool: true

uni_websocket:
  enabled: true

http_stream:
  enabled: true

sse:
  enabled: true

# ============================================
# 引擎配置 - 开发环境使用内存引擎
# ============================================
engine:
  type: memory

# ============================================
# 客户端连接配置
# ============================================
client:
  # 开发环境：允许所有来源
  allowed_origins:
    - "*"
  
  # 允许匿名连接（不需要 JWT token）
  allow_anonymous_connect_without_token: true

  ping_interval: 30s
  pong_timeout: 8s
  connection_limit: 1000
  user_connection_limit: 100

# ============================================
# 管理后台与监控
# ============================================
admin:
  enabled: true

health:
  enabled: true

prometheus:
  enabled: true

# ============================================
# 日志配置
# ============================================
log:
  level: "debug"  # 开发环境使用 debug 级别
  format: "text"   # 开发环境使用文本格式，便于查看

# ============================================
# 通道命名空间配置
# ============================================
channel:
  namespaces:
    - name: public
      presence: true
      join_leave: true
      history_size: 10
      history_ttl: "300s"
      force_recovery: true
      allow_publish_for_subscriber: true
      allow_subscribe_for_client: true
    
    - name: private
      presence: true
      join_leave: true
      history_size: 10
      history_ttl: "300s"
      force_recovery: true
      allow_publish_for_subscriber: false
      allow_subscribe_for_client: false
```

### Docker Compose 配置 (`centrifugo/docker-compose.yml`)
```yaml
services:
  centrifugo:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        CENTRIFUGO_VERSION: 6.8.1
    container_name: centrifugo
    command: centrifugo -c /centrifugo/config.yaml
    volumes:
      - ${CONFIG_PATH}centrifugo:/centrifugo
    environment:
      - CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY=${CENTRIFUGO_TOKEN_HMAC_SECRET_KEY}
      - CENTRIFUGO_HTTP_API_KEY=${CENTRIFUGO_API_KEY}
      - CENTRIFUGO_ADMIN_PASSWORD=${CENTRIFUGO_ADMIN_PASSWORD}
      - CENTRIFUGO_ADMIN_SECRET=${CENTRIFUGO_ADMIN_SECRET}
      - CENTRIFUGO_ENGINE_REDIS_ADDRESS=redis://:${REDIS_PASSWORD}@valkey:6379/2
      - CENTRIFUGO_CLIENT_ALLOWED_ORIGINS=["*"]
      - CENTRIFUGO_LOG_LEVEL=info
      - CENTRIFUGO_LOG_FORMAT=json
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
    restart: always
    networks:
      - backend
      - frontend
    depends_on:
      valkey:
        condition: service_healthy
```

---

## 4. 验证计划

### A. 静态验证
1. 运行 `hadolint Dockerfile` 进行 Dockerfile 静态语法和安全检查。
2. 运行 `docker compose config` 检查 compose 文件语法的正确性。

### B. 动态与运行时验证
1. **构建验证**：运行 `docker compose build centrifugo` 以验证镜像能否顺利完成构建。
2. **时区验证**：启动容器后，执行 `docker exec centrifugo date` 确认时间是否与宿主机及上海时区一致。
3. **健康检查验证**：执行 `docker inspect --format='{{json .State.Health}}' centrifugo` 确认健康检查状态最终转为 `healthy`。
4. **服务连通与日志验证**：在宿主机使用 WebSocket 测试工具连接，确认连接成功，并确认 `docker logs centrifugo` 能输出符合预期的 JSON 日志。
