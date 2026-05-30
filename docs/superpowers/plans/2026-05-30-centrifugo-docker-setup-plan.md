# Centrifugo Dockerfile 与最佳实践配置实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `centrifugo/` 文件夹下创建自定义 Dockerfile 并优化 `config.yaml` / `config-dev.yaml` / `docker-compose.yml` 使其满足生产级安全、时区、性能调优和健康检查的最佳实践。

**Architecture:** 基于官方 `centrifugo/centrifugo:6.8.1` (Alpine 底层) 轻量定制时区与权限目录。通过 `config.yaml` 定义协议与命名空间结构，动态凭证与细节配置使用 `CENTRIFUGO_` 前缀的环境变量在 `docker-compose.yml` 中进行注入与覆盖，实现开发文本日志/生产 JSON 日志的分离及非 root 容器运行安全。

**Tech Stack:** Centrifugo v6, Docker, Docker Compose, Valkey/Redis, Shell

---

### Task 1: 创建 Centrifugo Dockerfile

**Files:**
- Create: `centrifugo/Dockerfile`

- [ ] **Step 1: 编写 Dockerfile**
  在 `centrifugo/Dockerfile` 中输入以下内容：
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

- [ ] **Step 2: 使用 Hadolint 进行 Dockerfile 静态语法检查**
  运行：`rtk hadolint centrifugo/Dockerfile`
  预期输出：没有严重语法或安全警告（如有，根据 .hadolint.yaml 优化）。

- [ ] **Step 3: 提交修改**
  运行：
  ```bash
  rtk git add centrifugo/Dockerfile
  rtk git commit -m "feat(centrifugo): add custom Dockerfile with timezone and healthcheck"
  ```

---

### Task 2: 优化生产环境配置 `config.yaml`

**Files:**
- Modify: `centrifugo/config.yaml`

- [ ] **Step 1: 写入 config.yaml 生产最佳实践配置**
  修改 `centrifugo/config.yaml` 的内容为：
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
      # 具体的连接地址通过环境变量 CENTRIFUGO_ENGINE_REDIS_ADDRESS 动态注入
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
    # 密码和密钥将通过环境变量注入

  health:
    enabled: true

  prometheus:
    enabled: true

  # ============================================
  # 日志配置
  # ============================================
  log:
    level: info
    format: json # 生产环境输出 JSON

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

- [ ] **Step 2: 提交修改**
  运行：
  ```bash
  rtk git add centrifugo/config.yaml
  rtk git commit -m "chore(centrifugo): optimize config.yaml with production best practices"
  ```

---

### Task 3: 优化开发环境配置 `config-dev.yaml`

**Files:**
- Modify: `centrifugo/config-dev.yaml`

- [ ] **Step 1: 写入 config-dev.yaml 开发环境配置**
  修改 `centrifugo/config-dev.yaml` 的内容为：
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

- [ ] **Step 2: 提交修改**
  运行：
  ```bash
  rtk git add centrifugo/config-dev.yaml
  rtk git commit -m "chore(centrifugo): simplify config-dev.yaml for local development"
  ```

---

### Task 4: 更新 Docker Compose 配置 `docker-compose.yml`

**Files:**
- Modify: `centrifugo/docker-compose.yml`

- [ ] **Step 1: 修改 docker-compose.yml 服务声明**
  修改 `centrifugo/docker-compose.yml` 内容为：
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

- [ ] **Step 2: 验证 Docker Compose 语法有效性**
  在项目根目录下运行：`rtk docker compose config`
  预期输出：打印合并后的 compose 配置文件，没有错误。

- [ ] **Step 3: 提交修改**
  运行：
  ```bash
  rtk git add centrifugo/docker-compose.yml
  rtk git commit -m "feat(centrifugo): integrate custom Dockerfile build in docker-compose.yml"
  ```

---

### Task 5: 验证服务构建与启动状态

- [ ] **Step 1: 构建本地镜像**
  运行：`rtk docker compose build centrifugo`
  预期输出：构建成功。

- [ ] **Step 2: 启动 Valkey 与 Centrifugo 依赖服务**
  运行：`rtk docker compose up -d valkey centrifugo`
  预期输出：Valkey 和 Centrifugo 正常创建并处于 Running 状态。

- [ ] **Step 3: 检查时区一致性**
  运行：`rtk docker exec centrifugo date`
  预期输出：输出当前系统时间，带 CST（中国标准时间）时区标识。

- [ ] **Step 4: 检查健康状况**
  运行：`rtk docker inspect --format='{{json .State.Health}}' centrifugo`
  预期输出：`"Status":"healthy"` 且失败次数为 0。

- [ ] **Step 5: 验证 HTTP 健康接口返回**
  运行：`rtk docker exec centrifugo wget -qO- http://localhost:8000/health`
  预期输出：`OK`，或者 HTTP 状态码 200。

- [ ] **Step 6: 查看 JSON 格式日志**
  运行：`rtk docker compose logs centrifugo --tail 20`
  预期输出：每一条日志均以 JSON 格式输出，例如包含 `"level":"info"`, `"message":"..."` 字段。

- [ ] **Step 7: 停止测试容器并清理环境**
  运行：`rtk docker compose down`
  预期输出：容器已优雅退出并删除。
