# Mosquitto 生产级部署与 Caddy 代理实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现生产级别的 Mosquitto MQTT Broker 部署，支持静态多用户密码动态生成与 ACL 隔离，并通过 Caddy 代理 WebSockets (WSS) 实现 TLS 卸载。

**Architecture:** Mosquitto 监听 1883 (MQTT TCP) 和 9001 (MQTT WebSocket) 端口。启动入口脚本自动拷贝只读模板防止挂载遮蔽，并读取 `MQTT_USERS` 解析多账户追加至 `passwd`。外部 Caddy 通过 443 (HTTPS) 端口反向代理长连接至 Mosquitto WebSockets 端口，实现域名级证书卸载，并精简日志以降低磁盘占用。

**Tech Stack:** Docker, Docker Compose, Eclipse-Mosquitto, Caddy

---

### Task 1: 初始化备份配置模板与改造 Dockerfile

**Files:**
- Create: `mosquitto/config/acl.default`
- Modify: `mosquitto/Dockerfile`

- [ ] **Step 1: 创建默认 ACL 模板文件**
  
  创建 `mosquitto/config/acl.default` 并输入以下内容：
  ```ini
  # ============================================================================
  # 生产环境默认访问控制列表 (ACL) 模板
  # ============================================================================

  # 管理员用户拥有对所有主题的完全访问权限
  user admin
  topic readwrite #
  topic readwrite $SYS/#

  # 示例设备用户权限隔离 (设备仅能读写自己的 telemetry 主题)
  # user device_01
  # topic readwrite device/device_01/telemetry
  # topic read device/device_01/command

  # 示例只读监控账户
  # user monitor
  # topic read $SYS/#
  ```

- [ ] **Step 2: 修改 Dockerfile**

  修改 `mosquitto/Dockerfile` 为如下内容（在构建时同时打包默认的 `mosquitto.conf` 和 `acl.default` 到备份目录 `/etc/mosquitto.templates`）：
  ```dockerfile
  ARG MOSQUITTO_VERSION=2.1.2-alpine
  FROM eclipse-mosquitto:${MOSQUITTO_VERSION}

  ARG CHANGE_SOURCE=true
  ARG TIMEZONE=Asia/Shanghai
  RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
      sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories; \
      fi && \
      apk add --no-cache tzdata && \
      ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
      echo "${TIMEZONE}" > /etc/timezone

  ENV DEV=true

  # 将配置复制到默认运行目录
  COPY config/*.conf /mosquitto/config/
  COPY config/acl.default /mosquitto/config/acl.default

  # 同时创建一份只读的备份模板，以防止宿主机空挂载遮蔽配置
  RUN mkdir -p /etc/mosquitto.templates && \
      cp /mosquitto/config/mosquitto.conf /etc/mosquitto.templates/mosquitto.conf && \
      cp /mosquitto/config/acl.default /etc/mosquitto.templates/acl

  COPY startup.sh /usr/local/bin/startup.sh
  COPY healthcheck.sh /usr/local/bin/healthcheck.sh

  RUN chmod +x /usr/local/bin/startup.sh && \
      chmod +x /usr/local/bin/healthcheck.sh

  # 健康检查（支持认证）
  HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
      CMD /usr/local/bin/healthcheck.sh

  # 设置启动命令
  ENTRYPOINT ["/usr/local/bin/startup.sh"]

  CMD ["mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
  ```

- [ ] **Step 3: 提交代码**

  Run: `git add mosquitto/config/acl.default mosquitto/Dockerfile`
  Run: `git commit -m "feat: setup configuration templates and Dockerfile for backup"`

---

### Task 2: 改造启动入口脚本 startup.sh

**Files:**
- Modify: `mosquitto/startup.sh`

- [ ] **Step 1: 编写多用户及空卷拷贝逻辑**

  将 `mosquitto/startup.sh` 修改为如下内容：
  ```bash
  #!/bin/sh
  set -e

  # 日志函数
  log_info() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
  }

  log_success() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
  }

  log_warning() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
  }

  log_error() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
  }

  log_info "=========================================="
  log_info "Mosquitto MQTT Broker 启动配置初始化与验证"
  log_info "=========================================="

  # 1. 检查并处理空挂载目录遮蔽问题
  if [ ! -f /mosquitto/config/mosquitto.conf ]; then
      log_warning "未检测到 /mosquitto/config/mosquitto.conf，正在从模板初始化配置..."
      cp /etc/mosquitto.templates/mosquitto.conf /mosquitto/config/mosquitto.conf
      log_success "默认 mosquitto.conf 已复制"
  fi

  if [ ! -f /mosquitto/config/acl ]; then
      log_info "未检测到 /mosquitto/config/acl，正在初始化默认的 acl 策略..."
      cp /etc/mosquitto.templates/acl /mosquitto/config/acl
      log_success "默认 acl 已复制"
  fi

  # 确保运行权限
  chmod 644 /mosquitto/config/mosquitto.conf
  chmod 644 /mosquitto/config/acl

  # 2. 配置验证函数
  validate_config() {
      local errors=0
      
      # 检查 MQTT_ALLOW_ANONYMOUS 配置
      if [ -z "$MQTT_ALLOW_ANONYMOUS" ]; then
          log_warning "MQTT_ALLOW_ANONYMOUS 未设置，默认为 false"
          MQTT_ALLOW_ANONYMOUS="false"
      fi
      
      # 如果禁用匿名访问，必须设置主用户名密码或配置了多用户
      if [ "$MQTT_ALLOW_ANONYMOUS" = "false" ]; then
          if [ -z "$MQTT_USERNAME" ] && [ -z "$MQTT_USERS" ]; then
              log_error "禁用匿名访问时，必须设置主管理员（MQTT_USERNAME）或配置多账户（MQTT_USERS）"
              errors=$((errors + 1))
          else
              log_success "认证配置: 账号密码验证已启用"
          fi
      else
          log_warning "匿名访问已启用，这在生产环境存在极高安全风险"
      fi
      
      # 如果有错误，退出
      if [ $errors -gt 0 ]; then
          log_info "=========================================="
          log_error "配置验证失败，发现 $errors 个错误"
          log_info "=========================================="
          exit 1
      fi
      
      log_success "配置验证通过"
  }

  # 执行配置验证
  validate_config

  # 3. 创建与生成密码文件
  # 初始化空的 passwd 文件
  touch /mosquitto/config/passwd
  chmod 0600 /mosquitto/config/passwd
  # 清空旧数据
  > /mosquitto/config/passwd

  # 写入主账号（如果存在）
  if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
      log_info "正在生成主管理员账户..."
      mosquitto_passwd -b /mosquitto/config/passwd "$MQTT_USERNAME" "$MQTT_PASSWORD"
      log_success "主管理员账号 $MQTT_USERNAME 写入完成"
  fi

  # 解析并写入环境变量指定的多用户（格式：u1:p1,u2:p2）
  if [ -n "$MQTT_USERS" ]; then
      log_info "正在生成多账户配置..."
      # 将逗号转换成换行以支持安全的循环读取，防止包含空格的复杂密码解析错位
      echo "$MQTT_USERS" | tr ',' '\n' | while read -r user_pair; do
          if [ -n "$user_pair" ]; then
              u=$(echo "$user_pair" | cut -d':' -f1)
              p=$(echo "$user_pair" | cut -d':' -f2-)
              if [ -n "$u" ] && [ -n "$p" ]; then
                  mosquitto_passwd -b /mosquitto/config/passwd "$u" "$p"
                  log_success "已成功添加用户: $u"
              fi
          fi
      done
  fi

  log_info "=========================================="
  log_info "启动 Mosquitto MQTT Broker..."
  log_info "=========================================="

  # 启动 Mosquitto（移交控制权给自带入口，自动处理降权逻辑）
  exec /docker-entrypoint.sh "$@"
  ```

- [ ] **Step 2: 提交代码**

  Run: `git add mosquitto/startup.sh`
  Run: `git commit -m "feat: enhance startup.sh for directory init and multi-user authentication"`

---

### Task 3: 优化 mosquitto.conf 生产配置

**Files:**
- Modify: `mosquitto/config/mosquitto.conf`

- [ ] **Step 1: 修改 mosquitto.conf 内容**

  将 `mosquitto/config/mosquitto.conf` 修改为如下内容：
  ```ini
  # Mosquitto MQTT Broker 生产环境优化配置
  # 版本: 2.0.22 以上兼容

  # =================================================================
  # 监听器配置
  # =================================================================
  # TCP MQTT 监听器
  listener 1883 0.0.0.0
  protocol mqtt
  set_tcp_nodelay true

  # WebSockets 监听器 (提供给外部 Caddy 反代)
  listener 9001 0.0.0.0
  protocol websockets

  # =================================================================
  # 认证与安全
  # =================================================================
  password_file /mosquitto/config/passwd
  acl_file /mosquitto/config/acl
  allow_anonymous false

  # =================================================================
  # 持久化与会话
  # =================================================================
  persistence true
  persistence_location /mosquitto/data/
  persistence_file mosquitto.db
  # 自动保存间隔（秒）
  autosave_interval 300

  # 生产环境建议：过期清理 (1天)，防止持久客户端堆积导致性能下降
  persistent_client_expiration 1d

  # =================================================================
  # 资源限制 (预防 OOM 和恶意攻击)
  # =================================================================
  # 限制单个包大小 (10MB，保护内存)
  max_packet_size 10485760
  # 允许的最大并发连接 (-1 为无限制，受系统句柄限制)
  max_connections -1
  # QoS 1/2 待处理队列长度
  max_queued_messages 2000
  # 并发飞行消息数 (提高吞吐量)
  max_inflight_messages 40

  # =================================================================
  # 日志配置
  # =================================================================
  # 容器化环境仅输出到 stdout 方便日志聚合，关闭磁盘本地文件写入以减少 IO 损耗
  log_dest stdout

  # 生产环境仅记录 Error 和 Warning
  log_type error
  log_type warning

  connection_messages true
  log_timestamp true
  log_timestamp_format %Y-%m-%d %H:%M:%S

  # 系统状态更新频率 ($SYS 主题)，调大以减少内部开销
  sys_interval 60

  # =================================================================
  # 功能配置
  # =================================================================
  retain_available true
  allow_zero_length_clientid true
  auto_id_prefix auto-
  ```

- [ ] **Step 2: 提交代码**

  Run: `git add mosquitto/config/mosquitto.conf`
  Run: `git commit -m "feat: optimize mosquitto.conf with websockets listener, acl and optimized logging"`

---

### Task 4: 修改 Caddyfile 代理 WebSockets 流量

**Files:**
- Modify: `caddy/Caddyfile:62-68`

- [ ] **Step 1: 更新 Caddyfile 代理部分**

  将 `caddy/Caddyfile` 的下述代码段：
  ```caddyfile
  mqtt.{$SITE_ADDRESS} {
  	respond "MQTT Management Endpoint" 200
  	handle /health {
  		respond "OK" 200
  	}
  }
  ```
  修改替换为：
  ```caddyfile
  mqtt.{$SITE_ADDRESS} {
  	import ../snippets/request-log.conf
  	import ../snippets/security.conf
  	import ../snippets/waf.conf

  	encode zstd gzip

  	# 保留健康检查，用于网络探针检测
  	handle /health {
  		respond "OK" 200
  	}

  	# 代理所有其它流量（包括 WSS 连接请求）至 Mosquitto 的 9001 WebSockets 端口
  	handle {
  		reverse_proxy mosquitto:9001 {
  			header_up X-Accel-Buffering "no"
  			flush_interval -1
  			transport http {
  				dial_timeout 10s
  				response_header_timeout 30s
  				read_timeout 1h
  				write_timeout 1h
  			}
  		}
  	}
  }
  ```

- [ ] **Step 2: 提交代码**

  Run: `git add caddy/Caddyfile`
  Run: `git commit -m "feat: configure Caddy to proxy WSS connections to mosquitto:9001"`

---

### Task 5: 优化 docker-compose.yml 与主程序联动

**Files:**
- Modify: `mosquitto/docker-compose.yml`
- Modify: `docker-compose.yml`

- [ ] **Step 1: 修改 mosquitto/docker-compose.yml**

  将 `mosquitto/docker-compose.yml` 修改为如下内容（添加资源限制、句柄数优化，清除 log 卷挂载，向外物理暴露 1883）：
  ```yaml
  services:
    mosquitto:
      build:
        context: .
        args:
          - MOSQUITTO_VERSION=2.1.2-alpine
      container_name: mosquitto
      restart: always
      ports:
        - "${MQTT_PORT:-1883}:1883"
      volumes:
        - ${CONFIG_PATH}/mosquitto/config:/mosquitto/config
        - ${DATA_PATH}mosquitto/data:/mosquitto/data
      environment:
        - MQTT_USERNAME=${MQTT_USERNAME}
        - MQTT_PASSWORD=${MQTT_PASSWORD}
        - MQTT_USERS=${MQTT_USERS}
        - MQTT_ALLOW_ANONYMOUS=${MQTT_ALLOW_ANONYMOUS:-false}
        - SITE_ADDRESS=${SITE_ADDRESS}
      networks:
        - backend
        - frontend
      ulimits:
        nofile:
          soft: 65535
          hard: 65535
      deploy:
        resources:
          limits:
            cpus: '2.0'
            memory: 2048M
  ```

- [ ] **Step 2: 开启主 compose include 联动**

  修改根目录 `docker-compose.yml`：
  将以下注释行（第 90 行或相关位置）：
  ```yaml
  #  - mosquitto/docker-compose.yml    # MQTT 代理
  ```
  改为开启状态（注意，第 94 行如果重复，仅开启其中一行）：
  ```yaml
    - mosquitto/docker-compose.yml # MQTT 代理
  ```

- [ ] **Step 3: 提交代码**

  Run: `git add mosquitto/docker-compose.yml docker-compose.yml`
  Run: `git commit -m "feat: add resources limits, ulimits to mosquitto service and include it in main compose"`

---

### Task 6: 验证及集成测试

**Files:**
- Test: 自动化与手动网络连通性测试

- [ ] **Step 1: 本地环境构建与容器启动验证**

  首先在本地重新构建 mosquitto 镜像并启动容器。
  运行：`docker compose build mosquitto`
  运行：`docker compose up -d mosquitto caddy`
  验证：两个容器是否为 Running 状态。

- [ ] **Step 2: 验证空卷初始化机制**

  1. 停止 mosquitto：`docker compose stop mosquitto`
  2. 清理临时挂载数据（以宿主机实际挂载卷为准，可以在运行环境测试）。
  3. 重新启动：`docker compose start mosquitto`
  4. 检查日志：`docker compose logs mosquitto` 确认是否打印了 `[SUCCESS] 默认 mosquitto.conf 已复制` 和 `默认 acl 已复制` 的日志。

- [ ] **Step 3: 验证多用户与 ACL 生效情况**

  设置环境变量并重启容器：
  运行：`export MQTT_USERS="dev1:pass1,dev2:pass2" && docker compose up -d mosquitto`
  使用命令行工具（在测试终端或测试脚本中）验证：
  - 用 `dev1` 连入并发布消息测试。
  - 验证 ACL：默认模板只有管理员拥有 `#` 完全读写，可以在容器外部测试其他账号是否由于未设置 ACL 规则而受到限制。

- [ ] **Step 4: Caddy 反向代理 HTTP /health 测试**

  运行：`curl -I http://localhost/health` (如果绑定了 host) 或使用 `curl -I https://mqtt.your-domain.com/health` (配置完 hosts 时)。
  验证：返回 HTTP 200 OK 且 Response 包含 `OK`。

- [ ] **Step 5: 容器内并发句柄限制测试**

  运行：`docker compose exec mosquitto ulimit -n`
  验证输出为：`65535`。
