# Centrifugo v6 容器化部署与使用指南

本项目对 Centrifugo 进行了生产级容器化优化。采用**单配置文件 + 环境变量动态覆盖**的架构模式，消除了开发与生产环境的多配置文件冗余，并实现了统一的时区管理与非 root 运行时安全。

---

## 1. 架构组件

*   **Dockerfile**：基于官方 `centrifugo/centrifugo:v6.8.1` 镜像进行轻量级定制，添加了 `Asia/Shanghai` 时区支持、非 root 用户（`centrifugo`）安全限制和内置的 `/health` 健康检查。
*   **config.yaml**：统一的事实源配置文件，管理核心传输协议和通道命名空间（Namespaces）。
*   **docker-compose.yml**：通过环境变量在容器启动时动态调整配置，划分开发与生产行为。

---

## 2. 运行与环境切换

所有差异化配置全部由环境变量控制，避免了重复修改配置文件。

### A. 开发环境 (Memory 内存引擎)
开发环境无需依赖 Valkey/Redis，使用单机内存引擎即可。

**在 `.env` 或启动命令中设置以下环境变量**：
```env
# 覆盖引擎类型为 memory 内存引擎
CENTRIFUGO_ENGINE_TYPE=memory

# 允许匿名连接，方便本地调试
CENTRIFUGO_CLIENT_ALLOW_ANONYMOUS_CONNECT_WITHOUT_TOKEN=true

# 允许所有跨域请求
CENTRIFUGO_ALLOWED_ORIGINS=*

# 开启 Debug 日志级别
CENTRIFUGO_LOG_LEVEL=debug
```

**启动服务**：
```bash
docker compose up -d centrifugo
```

---

### B. 生产环境 (Valkey 分布式引擎)
生产环境使用 Valkey 引擎支持多节点集群与状态持久化。

**在生产环境 `.env` 中配置**：
```env
# 使用 redis 引擎（兼容 Valkey）
CENTRIFUGO_ENGINE_TYPE=redis

# 生产环境强制 JWT 认证，禁用匿名连接
CENTRIFUGO_CLIENT_ALLOW_ANONYMOUS_CONNECT_WITHOUT_TOKEN=false

# 限制 CORS 跨域源（支持填写具体的可信域名，格式如 ["https://yourdomain.com"]）
CENTRIFUGO_ALLOWED_ORIGINS=https://push.yourdomain.com

# 锁定 info 级别日志
CENTRIFUGO_LOG_LEVEL=info

# 敏感密钥凭证 (确保为强随机密钥)
CENTRIFUGO_TOKEN_HMAC_SECRET_KEY=your-production-jwt-secret-key
CENTRIFUGO_API_KEY=your-production-http-api-key
CENTRIFUGO_ADMIN_PASSWORD=your-admin-password
CENTRIFUGO_ADMIN_SECRET=your-admin-secret
```

**启动服务**：
```bash
docker compose up -d valkey centrifugo
```

---

## 3. 核心环境变量映射

Centrifugo 支持以 `CENTRIFUGO_` 为前缀的环境变量，自动映射合并到 `config.yaml` 对应配置中：

| 环境变量 | 对应 YAML 配置项 | 描述 |
| :--- | :--- | :--- |
| `CENTRIFUGO_ENGINE_TYPE` | `engine.type` | 引擎类型，可选 `redis` / `memory` |
| `CENTRIFUGO_ENGINE_REDIS_ADDRESS` | `engine.redis.address` | Valkey/Redis 连接地址 |
| `CENTRIFUGO_CLIENT_ALLOW_ANONYMOUS_CONNECT_WITHOUT_TOKEN` | `client.allow_anonymous_connect_without_token` | 是否允许匿名连接（安全控制） |
| `CENTRIFUGO_CLIENT_ALLOWED_ORIGINS` | `client.allowed_origins` | CORS 域名数组格式，例如 `["https://a.com"]` |
| `CENTRIFUGO_LOG_LEVEL` | `log.level` | 日志级别：`debug` / `info` / `warn` / `error` |

---

## 4. 命名空间最佳实践

配置文件中预设了四个命名空间，满足常见业务场景：

1.  **`public` (公共频道)**：
    *   允许客户端订阅和发布。
    *   适用于聊天室、在线广播等。
2.  **`private` (私有频道)**：
    *   必须提供订阅 Token（JWT）才能订阅。
    *   不允许客户端直接发布（只允许后端服务通过 HTTP API 推送）。
    *   适用于单对单聊天、私密数据推送。
3.  **`user` (用户个人频道)**：
    *   用户专属消息通道，自动校验用户 ID。
    *   适用于个人系统通知、红点提醒。
4.  **`notification` (通知频道)**：
    *   轻量级的通知通道，不强制要求恢复历史，保留较短的 TTL。

---

## 5. 健康检查与监控

### 健康检查
Dockerfile 已经内置了健康检查命令，每 10 秒自动运行一次：
```bash
# 容器内检查命令
wget -qO- http://localhost:8000/health
```
在宿主机上，可通过以下命令查看容器状态：
```bash
docker compose ps centrifugo
# 状态应显示为 (healthy)
```

### Prometheus 监控指标
监控端口默认为 `8000`，获取指标的端点为：
```http
http://localhost:8000/metrics
```

---

## 6. 日志格式与收集
在 Centrifugo v6 中，标准输出日志默认输出为**结构化的 JSON 格式**（不再需要配置 `log.format`），以便无缝对接本项目中的 Loki / Vector / ELK 日志收集系统。

```bash
# 查看实时日志
docker compose logs centrifugo -f
```

---

## 7. 常见问题排查

1.  **连接失败 (CORS 错误)**
    *   检查宿主机环境的 `.env` 中 `CENTRIFUGO_ALLOWED_ORIGINS` 的设置。本地开发建议为 `*`。
2.  **日志警告 `unknown var in environment`**
    *   不要使用旧版的废弃环境变量（例如 `CENTRIFUGO_LOG_FORMAT`、`CENTRIFUGO_REDIS_POOL` 等）。请严格对照本文档的环境变量映射表进行配置。
3.  **时区不对**
    *   由于我们使用的是自定义 Dockerfile 构建，在更新过 `config.yaml` 或基础配置后，请运行 `docker compose build centrifugo --no-cache` 重新构建镜像以应用时区和配置更新。
