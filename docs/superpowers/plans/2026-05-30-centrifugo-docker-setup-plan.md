# Centrifugo Dockerfile 与最佳实践单文件配置实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `centrifugo/` 文件夹下创建自定义 Dockerfile，删除冗余的 `config-dev.yaml`，并优化 `config.yaml` / `docker-compose.yml` 使其满足生产级安全、时区、性能调优和健康检查的最佳实践，彻底消除 v6 废弃配置导致的日志告警。

**Architecture:** 基于官方 `centrifugo/centrifugo:v6.8.1` (Alpine 底层) 定制时区与权限目录。统一使用 `config.yaml` 维护核心业务协议和通道命名空间（Namespaces）。环境差异（如引擎类型、匿名连接许可、日志级别）以及动态凭证完全通过 Docker Compose 的环境变量在容器启动时覆盖。

**Tech Stack:** Centrifugo v6, Docker, Docker Compose, Valkey/Redis, Shell

---

### Task 1: 创建 Centrifugo Dockerfile (只拷贝 config.yaml)

**Files:**
- Create: `centrifugo/Dockerfile`

- [ ] **Step 1: 编写 Dockerfile**
  在 `centrifugo/Dockerfile` 中输入以下内容：
  ```dockerfile
  # 锁定 Centrifugo 版本
  ARG CENTRIFUGO_VERSION=v6.8.1
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

  # 仅复制单配置文件 config.yaml 到容器中
  COPY --chown=centrifugo:centrifugo config.yaml /centrifugo/config.yaml

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
  预期输出：没有严重语法或安全警告。

- [ ] **Step 3: 提交修改**
  运行：
  ```bash
  rtk git add centrifugo/Dockerfile
  rtk git commit -m "feat(centrifugo): add custom Dockerfile with timezone and healthcheck"
  ```

---

### Task 2: 编写统一的配置文件 `config.yaml` 并在 Git 中删除 `config-dev.yaml`

**Files:**
- Modify: `centrifugo/config.yaml`
- Delete: `centrifugo/config-dev.yaml`

- [ ] **Step 1: 写入 config.yaml 统一配置**
  修改 `centrifugo/config.yaml`，去除 v6 废弃 Redis pool/timeout/log_format 配置以消除警告：
  ```yaml
  # Centrifugo v6 统一基础配置
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
  # 引擎配置 - 默认在 config 中声明 redis
  # 具体的 engine 类型和 redis address 由环境变量动态覆盖
  # ============================================
  engine: redis
  engine_redis:
    # 具体的连接地址通过环境变量 CENTRIFUGO_ENGINE_REDIS_ADDRESS 动态注入
    # v6 默认使用 Rueidis 客户端进行连接复用，无须配置 pool_size
    connect_timeout: "1s"
    io_timeout: "4s"

  # ============================================
  # 客户端连接配置
  # ============================================
  client:
    # 默认禁止匿名连接，安全至上；开发环境通过环境变量覆盖为 true
    allow_anonymous_connect_without_token: false
    
    # 跨域列表默认空，由环境变量覆盖
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

  health:
    enabled: true

  prometheus:
    enabled: true

  # ============================================
  # 日志配置
  # ============================================
  log:
    level: info  # 日志级别由环境变量 CENTRIFUGO_LOG_LEVEL 覆盖

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

- [ ] **Step 2: 用 Git 删除 config-dev.yaml**
  运行：`rtk git rm centrifugo/config-dev.yaml`
  预期输出：成功从仓库中删除。

- [ ] **Step 3: 提交配置修改**
  运行：
  ```bash
  rtk git add centrifugo/config.yaml
  rtk git commit -m "chore(centrifugo): unify configuration into config.yaml and delete config-dev.yaml"
  ```

---

### Task 3: 更新 Docker Compose 配置 `docker-compose.yml` 并支持环境覆盖

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
          CENTRIFUGO_VERSION: v6.8.1
      container_name: centrifugo
      command: centrifugo -c /centrifugo/config.yaml
      volumes:
        - ${CONFIG_PATH}centrifugo:/centrifugo
      environment:
        # 默认使用 redis 引擎，但可以在开发环境的 .env 中通过 CENTRIFUGO_ENGINE 设定为 memory
        - CENTRIFUGO_ENGINE=${CENTRIFUGO_ENGINE:-redis}
        # 基础秘钥与凭证
        - CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY=${CENTRIFUGO_TOKEN_HMAC_SECRET_KEY}
        - CENTRIFUGO_HTTP_API_KEY=${CENTRIFUGO_API_KEY}
        - CENTRIFUGO_ADMIN_PASSWORD=${CENTRIFUGO_ADMIN_PASSWORD}
        - CENTRIFUGO_ADMIN_SECRET=${CENTRIFUGO_ADMIN_SECRET}
        # Redis 引擎的 Valkey 连接地址
        - CENTRIFUGO_ENGINE_REDIS_ADDRESS=redis://:${REDIS_PASSWORD}@valkey:6379/2
        # CORS 允许的域：从 .env 中的 CENTRIFUGO_ALLOWED_ORIGINS 映射为 JSON 格式数组
        - CENTRIFUGO_CLIENT_ALLOWED_ORIGINS=["${CENTRIFUGO_ALLOWED_ORIGINS:-*}"]
        # 日志等级：允许通过环境变量修改
        - CENTRIFUGO_LOG_LEVEL=${CENTRIFUGO_LOG_LEVEL:-info}
        # 匿名连接控制：开发环境默认为 true，生产环境可在 .env 中重写为 false
        - CENTRIFUGO_CLIENT_ALLOW_ANONYMOUS_CONNECT_WITHOUT_TOKEN=${CENTRIFUGO_ALLOW_ANONYMOUS_CONNECT_WITHOUT_TOKEN:-false}
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
  rtk git commit -m "feat(centrifugo): configure compose file to use environment-based overrides for single-config setup"
  ```

---

### Task 4: 验证单文件服务构建与启动状态 (彻底消除日志报警)

- [ ] **Step 1: 构建本地镜像**
  运行：`rtk docker compose build centrifugo`
  预期输出：构建成功。

- [ ] **Step 2: 启动 Valkey 与 Centrifugo 依赖服务**
  运行：`rtk docker compose up -d valkey centrifugo`
  预期输出：Valkey 和 Centrifugo 正常创建并处于 Running 状态。

- [ ] **Step 3: 检查时区一致性**
  运行：`rtk docker exec centrifugo date`
  预期输出：输出当前系统时间，带 CST 时区标识。

- [ ] **Step 4: 检查健康状况**
  运行：`rtk docker inspect --format='{{json .State.Health}}' centrifugo`
  预期输出：`"Status":"healthy"` 且失败次数为 0。

- [ ] **Step 5: 验证 HTTP 健康接口返回**
  运行：`rtk docker exec centrifugo wget -qO- http://localhost:8000/health`
  预期输出：`{}`, 说明返回了 200。

- [ ] **Step 6: 查看 JSON 格式日志 (验证警告完全消除)**
  运行：`rtk proxy docker compose logs centrifugo`
  预期输出：没有任何 `"level":"warn"` 的 `unknown key` 报错。只输出 info 日志，表示完美集成。

- [ ] **Step 7: 停止测试容器并清理环境**
  运行：`rtk docker compose down`
  预期输出：容器已优雅退出并删除。
