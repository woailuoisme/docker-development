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

配置文件中预设了四个命名空间，满足常见业务场景。设计与配置要点如下：

1.  **`public` (公开频道)**：
    *   **适用场景**：聊天室、大厅、公开广播等。
    *   **配置特性**：允许客户端直接发布和订阅（`allow_publish_for_subscriber: true`）。
    *   **可靠性保证**：开启历史记录并设置大小为 100 且强制恢复（`force_recovery: true`），防止客户端在移动端弱网状态重连时丢失未送达的历史消息。
    *   **安全要求**：开发环境允许匿名订阅；生产环境建议禁用匿名，通过环境变量要求 Token 认证。
2.  **`private` (私有频道)**：
    *   **适用场景**：单对单聊天、私密数据推送。
    *   **配置特性**：禁用客户端直接发布（`allow_publish_for_subscriber: false`），必须由后端接口经过业务校验后再使用 HTTP API 推送。
    *   **安全要求**：禁用客户端直接订阅（`allow_subscribe_for_client: false`），订阅时必须向后端请求签发的订阅 Token（JWT）进行授权。
3.  **`user` (用户个人频道)**：
    *   **适用场景**：用户专属消息通道，例如红点提醒、个人系统通知。
    *   **配置特性**：禁用 `presence` 和 `join_leave` 统计（个人专属频道不需要监听其他人在不在状态），极大节省并发下的内存和 CPU 资源。开启恢复保证（`force_recovery: true`）确保通知必达。
4.  **`notification` (通知频道)**：
    *   **适用场景**：全局非关键实时广播（如系统维护通知、实时滚动公告）。
    *   **配置特性**：高吞吐低敏感。缩短历史 TTL（`60s`）并关闭强制恢复以极大减轻 Valkey/Redis 内存缓存的持久化与网络同步压力。

---

## 5. SSE 与 Unidirectional SSE (单向推送) 使用指南

除了传统的 WebSocket，本项目还开启了 **SSE (Server-Sent Events)** 支持。尤其是 **Unidirectional SSE (单向推送)**，允许前端直接使用浏览器原生的 `EventSource` API 与 Centrifugo 通信，而无需加载专用的 JavaScript SDK，极大地简化了客户端代码。

### 客户端接入说明：

#### A. 浏览器原生 EventSource 接入 (Unidirectional SSE)
客户端仅需向 `/connection/uni_sse` 发起 `GET` 请求。因为 `EventSource` 无法自定义 Header，连接时的认证 Token 或需要订阅的频道需通过 `cf_connect` 网址查询参数传递（传入转义的 JSON 字符串）：

```javascript
// 准备连接参数
const connectParams = {
  // 开发环境匿名连接需指定直接订阅的频道
  channels: ["public:test"]
  
  // 生产环境需携带 JWT Token
  // token: "YOUR_JWT_TOKEN"
};

// 拼接连接 URL
const url = new URL("http://localhost:8000/connection/uni_sse");
url.searchParams.append("cf_connect", JSON.stringify(connectParams));

// 初始化 EventSource
const eventSource = new EventSource(url);

// 监听服务器端推送的消息
eventSource.onmessage = function(event) {
  const message = JSON.parse(event.data);
  console.log("收到推送数据：", message);
};

eventSource.onerror = function(err) {
  console.error("SSE 连接出错：", err);
};
```

#### B. 使用 Centrifuge-JS SDK 接入 (Bidirectional SSE)
如果希望通过 SSE 传输并使用 SDK 内置的频道订阅管理，可以在客户端初始化时指定 `transport` 为 `sse`：

```javascript
import { Centrifuge } from 'centrifuge';

const centrifuge = new Centrifuge('http://localhost:8000/connection/sse', {
  transport: 'sse',
  token: 'YOUR_JWT_TOKEN' // 匿名连接在开发环境可省略
});

const sub = centrifuge.newSubscription('public:test');
sub.on('publication', function(ctx) {
  console.log('收到 SDK 消息:', ctx.data);
});

sub.subscribe();
centrifuge.connect();
```

---

## 6. 健康检查与监控

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

## 7. 日志格式与收集
在 Centrifugo v6 中，标准输出日志默认输出为**结构化的 JSON 格式**（不再需要配置 `log.format`），以便无缝对接本项目中的 Loki / Vector / ELK 日志收集系统。

```bash
# 查看实时日志
docker compose logs centrifugo -f
```

---

## 8. 常见问题排查

1.  **连接失败 (CORS 错误)**
    *   检查宿主机环境的 `.env` 中 `CENTRIFUGO_ALLOWED_ORIGINS` 的设置。本地开发建议为 `*`。
2.  **日志警告 `unknown var in environment`**
    *   不要使用旧版的废弃环境变量（例如 `CENTRIFUGO_LOG_FORMAT`、`CENTRIFUGO_REDIS_POOL` 等）。请严格对照本文档的环境变量映射表进行配置。
3.  **时区不对**
    *   由于我们使用的是自定义 Dockerfile 构建，在更新过 `config.yaml` 或基础配置后，请运行 `docker compose build centrifugo --no-cache` 重新构建镜像以应用时区和配置更新。
