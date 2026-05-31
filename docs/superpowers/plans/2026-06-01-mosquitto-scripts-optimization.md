# Mosquitto 脚本简化与优化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 简化和优化 Mosquitto 中的 `startup.sh` 和 `healthcheck.sh` 脚本，移除多余时间戳、使用 Shell 内置参数提取代替 cut 外部命令，并引入 exec 和单引号机制减少健康检查开销。

**Architecture:** 改造后的 `startup.sh` 输出极其精炼，完全消除了循环内 cut 进程开销；`healthcheck.sh` 精简分支逻辑并使用 `exec` 挂载 `mosquitto_sub` 以接管容器进程退出状态。

**Tech Stack:** Shell (POSIX compliant / Alpine Busybox ash)

---

### Task 1: 优化健康检查脚本 healthcheck.sh

**Files:**
- Modify: `mosquitto/healthcheck.sh`

- [ ] **Step 1: 修改 healthcheck.sh**

  将 `mosquitto/healthcheck.sh` 修改为如下内容（精简变量引用，加入 exec 接管，单引号直接传参）：
  ```bash
  #!/bin/sh
  # Mosquitto 生产级健康检查脚本
  # 支持认证和匿名模式

  # 如果设置了用户名和密码，使用认证连入本地
  if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
      exec /usr/bin/mosquitto_sub \
          -h localhost \
          -p 1883 \
          -u "$MQTT_USERNAME" \
          -P "$MQTT_PASSWORD" \
          -t '$SYS/broker/uptime' \
          -C 1 \
          > /dev/null 2>&1
  else
      # 匿名连接测试
      exec /usr/bin/mosquitto_sub \
          -h localhost \
          -p 1883 \
          -t '$SYS/broker/uptime' \
          -C 1 \
          > /dev/null 2>&1
  fi
  ```

- [ ] **Step 2: 静态语法校验**

  在终端进行 Shell 静态语法校验：
  Run: `shellcheck mosquitto/healthcheck.sh`
  Expected: 无任何报错或警告信息。

- [ ] **Step 3: 提交代码**

  Run: `git add mosquitto/healthcheck.sh`
  Run: `git commit -m "perf: simplify healthcheck.sh with process exec and single quotes for topic"`

---

### Task 2: 优化与简化 startup.sh 启动脚本

**Files:**
- Modify: `mosquitto/startup.sh`

- [ ] **Step 1: 修改 startup.sh**

  将 `mosquitto/startup.sh` 替换为以下精简的高效率内容：
  ```bash
  #!/bin/sh
  set -e

  echo "[INFO] Mosquitto MQTT Broker 启动配置初始化与验证"

  # 1. 检查并处理空挂载目录遮蔽问题
  if [ ! -f /mosquitto/config/mosquitto.conf ]; then
      echo "[WARN] 未检测到 /mosquitto/config/mosquitto.conf，正在从模板初始化配置..."
      cp /etc/mosquitto.templates/mosquitto.conf /mosquitto/config/mosquitto.conf
      echo "[SUCCESS] 默认 mosquitto.conf 已复制"
  fi

  if [ ! -f /mosquitto/config/acl ]; then
      echo "[INFO] 未检测到 /mosquitto/config/acl，正在初始化默认 acl 策略..."
      cp /etc/mosquitto.templates/acl /mosquitto/config/acl
      echo "[SUCCESS] 默认 acl 已复制"
  fi

  # 确保文件权限
  chmod 644 /mosquitto/config/mosquitto.conf
  chmod 644 /mosquitto/config/acl

  # 2. 配置验证函数
  validate_config() {
      # 检查 MQTT_ALLOW_ANONYMOUS 配置
      if [ -z "$MQTT_ALLOW_ANONYMOUS" ]; then
          echo "[WARN] MQTT_ALLOW_ANONYMOUS 未设置，默认为 false"
          MQTT_ALLOW_ANONYMOUS="false"
      fi
      
      # 如果禁用匿名访问，必须设置主用户名密码或配置了多用户
      if [ "$MQTT_ALLOW_ANONYMOUS" = "false" ]; then
          if [ -z "$MQTT_USERNAME" ] && [ -z "$MQTT_USERS" ]; then
              echo "[ERROR] 禁用匿名访问时，必须设置主管理员（MQTT_USERNAME）或配置多账户（MQTT_USERS）"
              exit 1
          else
              echo "[SUCCESS] 认证配置: 账号密码验证已启用"
          fi
      else
          echo "[WARN] 匿名访问已启用，这在生产环境存在极高安全风险"
      fi
  }

  # 执行配置验证
  validate_config

  # 3. 创建与生成密码文件
  touch /mosquitto/config/passwd
  chmod 0600 /mosquitto/config/passwd
  true > /mosquitto/config/passwd # 清空旧数据

  # 写入主账号（如果存在）
  if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
      echo "[INFO] 正在生成主管理员账户..."
      mosquitto_passwd -b /mosquitto/config/passwd "$MQTT_USERNAME" "$MQTT_PASSWORD"
      echo "[SUCCESS] 主管理员账号 $MQTT_USERNAME 写入完成"
  fi

  # 解析并写入环境变量指定的多用户（格式：u1:p1,u2:p2）
  if [ -n "$MQTT_USERS" ]; then
      echo "[INFO] 正在生成多账户配置..."
      # 将逗号转换成换行以支持安全的循环读取
      echo "$MQTT_USERS" | tr ',' '\n' | while read -r user_pair; do
          if [ -n "$user_pair" ]; then
              # 使用 Shell 内置的参数替换切分语法，替代外部 cut 进程
              u="${user_pair%%:*}"
              p="${user_pair#*:}"
              if [ -n "$u" ] && [ -n "$p" ]; then
                  mosquitto_passwd -b /mosquitto/config/passwd "$u" "$p"
                  echo "[SUCCESS] 已成功添加用户: $u"
              fi
          fi
      done
  fi

  echo "[INFO] 启动 Mosquitto MQTT Broker..."

  # 启动 Mosquitto（移交控制权，自动处理降权逻辑）
  exec /docker-entrypoint.sh "$@"
  ```

- [ ] **Step 2: 静态语法校验**

  在终端进行 Shell 静态语法校验：
  Run: `shellcheck mosquitto/startup.sh`
  Expected: 无任何报错或警告信息。

- [ ] **Step 3: 提交代码**

  Run: `git add mosquitto/startup.sh`
  Run: `git commit -m "perf: simplify startup.sh with clean logging format and pure shell parsing"`

---

### Task 3: 本地构建与功能验证

**Files:**
- Test: 本地集成回归测试

- [ ] **Step 1: 构建并重启服务**

  使用 Compose 重新构建 mosquitto 服务并启动：
  Run: `docker compose build mosquitto && docker compose up -d mosquitto`
  Expected: 容器成功重建并以 Running 状态启动。

- [ ] **Step 2: 查看启动日志精简效果**

  检查容器启动输出日志：
  Run: `docker compose logs mosquitto`
  Expected: 日志无多余的装饰边框及手动时间戳前缀，风格简约，如下所示：
  ```
  [INFO] Mosquitto MQTT Broker 启动配置初始化与验证
  [SUCCESS] 认证配置: 账号密码验证已启用
  [INFO] 正在生成主管理员账户...
  Adding password for user admin
  [SUCCESS] 主管理员账号 admin 写入完成
  [INFO] 启动 Mosquitto MQTT Broker...
  ```

- [ ] **Step 3: 验证健康检查状态**

  等待 5-10 秒后检查容器健康状态：
  Run: `docker compose ps mosquitto`
  Expected: 容器的 STATUS 显示为 `Up` 且标记为 `(healthy)`。
