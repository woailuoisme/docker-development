# 生产级 Mosquitto MQTT Broker 部署与 Caddy 代理设计方案

本文档定义了生产级别 Mosquitto MQTT Broker 容器化部署、多用户及 ACL 权限管理，以及通过 Caddy 网关进行 TLS/SSL 卸载与 WebSockets 反向代理的设计规约。

---

## 1. 背景与目标

当前环境中的 Mosquitto 配置较为基础，单用户认证机制无法满足生产环境下多客户端隔离的安全要求，且缺少主题访问控制（ACL）。同时，在容器挂载外部存储卷时，存在“空卷遮蔽”容器内默认配置文件导致闪退的问题。

本方案旨在：
1. **防遮蔽开箱即用**：挂载卷为空时，由容器启动脚本自动初始化配置文件。
2. **多用户与细粒度授权**：支持通过环境变量快速配置多个静态用户，并启用 ACL 限制。
3. **安全加密通信**：通过宿主机 Caddy 网关为 MQTT over WebSockets（WSS）自动处理 TLS 卸载。
4. **高并发与性能优化**：调优文件描述符限制，精简日志，配置 CPU 和内存资源限制防止 OOM，并给出宿主机网络内核调优建议。

---

## 2. 方案详解

### 2.1 容器配置防遮蔽与自动初始化

*   **Dockerfile 改造**
    *   在构建阶段，将 `config/mosquitto.conf` 和 `config/acl` 统一备份至 `/etc/mosquitto.templates/` 只读模板目录。
    *   容器保持以默认的 root 用户作为入口点启动，以便脚本进行文件读写及权限初始化，最终通过 `/docker-entrypoint.sh` 中的官方逻辑自动降权运行。
*   **启动入口脚本 (`startup.sh`) 改造**
    *   检查 `/mosquitto/config/mosquitto.conf` 是否存在。若不存在（例如首次部署宿主机挂载目录为空），则将 `/etc/mosquitto.templates/` 目录下的所有配置文件拷贝至挂载目录中，防止启动失败。

### 2.2 静态多用户与 ACL 认证授权

*   **环境变量多用户解析**
    *   支持 `MQTT_USERS` 环境变量（格式如：`user1:pass1,user2:pass2`），由 `startup.sh` 在启动时进行切分，使用 `mosquitto_passwd -b` 循环写入 `/mosquitto/config/passwd`，并自动设置 `chmod 0700`。
    *   继续兼容原有的 `MQTT_USERNAME` 和 `MQTT_PASSWORD` 变量作为主管理员账号。
*   **静态 ACL 规则激活**
    *   在 `mosquitto.conf` 中显式激活 `acl_file /mosquitto/config/acl`。
    *   默认提供一个合理的 `acl` 模板，指导管理员如何为不同用户（如管理员 `admin`、普通读写客户端、只读监控服务）划分 Topic 读写权限范围。

### 2.3 Caddy 反向代理 (WSS)

*   **双监听器配置**
    *   在 `mosquitto.conf` 中配置两个监听器：
        ```ini
        # 监听 1883 端口，用于内部服务或无加密设备直连
        listener 1883 0.0.0.0
        protocol mqtt
        set_tcp_nodelay true

        # 监听 9001 端口，用于 WebSocket 协议，供 Caddy 反代
        listener 9001 0.0.0.0
        protocol websockets
        ```
*   **Caddy 代理拦截 (`Caddyfile`)**
    *   配置域名 `mqtt.{$SITE_ADDRESS}` 的路由规则：
        *   保留对 `/health` 请求的拦截（直接响应 200 OK，便于外部心跳监控探测）。
        *   将其他所有长连接请求使用 `reverse_proxy mosquitto:9001` 代理至 Mosquitto。
        *   通过配置 `read_timeout 1h`、`write_timeout 1h` 以及 `flush_interval -1`，确保 MQTT over WebSockets 的长连接不断开且无额外响应延迟。

### 2.4 日志与资源配额调优

*   **精简日志输出**
    *   在 `mosquitto.conf` 中移除 `log_dest file` 配置，防止容器内本地日志堆积占满磁盘。
    *   仅保留 `log_dest stdout`，日志级别设为 `error` 和 `warning`，符合容器化日志收集最佳实践。
*   **容器句柄与硬件限制 (`mosquitto/docker-compose.yml`)**
    *   配置 `ulimits.nofile` 的 soft/hard 均为 `65535`，解除系统的最大并发连接数限制。
    *   配置 `deploy.resources.limits`，限制 CPU 上限为 2.0，内存上限为 2GB，以防高吞吐时对宿主机产生负面影响。
    *   移除 `log` 挂载目录的声明。

---

## 3. 宿主机内核参数优化建议

在高并发（连接数 > 10,000）场景下，建议在宿主机中优化以下内核参数（`/etc/sysctl.conf`）：

```ini
# 提高系统最大文件打开句柄数
fs.file-max = 2097152

# 增大 TCP 监听队列最大长度
net.core.somaxconn = 32768

# 增大处于半连接状态的 TCP 连接数
net.ipv4.tcp_max_syn_backlog = 16384

# 快速回收 TIME_WAIT 的 TCP 连接
net.ipv4.tcp_tw_reuse = 1

# 调大 TCP 缓冲区，提高数据传输吞吐量
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

---

## 4. 验证方案

1.  **开箱即用验证**：清空宿主机挂载的 `config` 文件夹，启动容器，检查是否自动生成了 `mosquitto.conf` 和 `acl`，且容器正常运行。
2.  **多用户验证**：配置环境变量 `MQTT_USERS="test_u1:test_p1,test_u2:test_p2"`，启动容器后进入容器内部检查 `/mosquitto/config/passwd` 的生成结果，使用 `mosquitto_sub` 及 `mosquitto_pub` 工具测试两个账号是否均可连入。
3.  **Caddy 代理验证**：通过 Caddy 服务对 `wss://mqtt.{$SITE_ADDRESS}` 发起 WebSocket 连接，测试能否成功建立 MQTT 握手并进行消息收发；请求 `https://mqtt.{$SITE_ADDRESS}/health` 应返回 `OK`。
4.  **句柄验证**：进入 `mosquitto` 容器，运行 `ulimit -n`，验证最大文件描述符数是否已升至 `65535`。
