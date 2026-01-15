# Centrifugo v6 配置说明

## 配置文件

- `config.yaml` - 生产环境配置（使用 Redis engine）
- `config-dev.yaml` - 开发环境配置（使用 memory engine）

## 环境切换

### 开发环境
```bash
# 使用开发配置启动
docker run -v ./centrifugo:/centrifugo centrifugo/centrifugo:v6 \
  centrifugo -c /centrifugo/config-dev.yaml
```

### 生产环境
```bash
# 使用生产配置启动（需要 Redis）
docker run -v ./centrifugo:/centrifugo centrifugo/centrifugo:v6 \
  centrifugo -c /centrifugo/config.yaml
```

## 生产环境配置要点

### 1. 引擎配置
- ✅ 使用 Redis engine 支持多节点集群
- ✅ 配置 Redis 连接池和超时
- ✅ 启用 presence_user_mapping 优化性能

### 2. 安全配置
- ✅ 限制 `allowed_origins` 到具体域名
- ✅ 使用强密码和密钥
- ✅ 启用 JWT 认证（移除 `allow_anonymous_connect_without_token`）
- ✅ 配置 TLS/SSL

### 3. 性能优化
- ✅ 设置合理的连接限制
- ✅ 配置速率限制
- ✅ 调整历史记录大小和 TTL
- ✅ 增加文件描述符限制（ulimit）

### 4. 监控和日志
- ✅ 启用 Prometheus metrics
- ✅ 配置健康检查端点
- ✅ 设置适当的日志级别（info）

### 5. 高可用部署
- ✅ 部署多个 Centrifugo 节点
- ✅ 使用 Redis Sentinel 或 Redis Cluster
- ✅ 配置负载均衡器（Nginx/Caddy）

## JWT 认证配置

生产环境应该启用 JWT 认证：

```yaml
client:
  # 移除匿名连接
  # allow_anonymous_connect_without_token: false
  
  # JWT 配置
  token:
    hmac_secret_key: "your-secret-key"
    # 或使用 RSA
    # rsa_public_key: "path/to/public.pem"
```

## 通道命名空间最佳实践

### public:* - 公共频道
- 允许客户端订阅和发布
- 适用于聊天室、公告等

### private:* - 私有频道
- 需要订阅 token
- 服务端控制访问权限

### user:{userId} - 用户个人频道
- 用户专属通知
- 不需要历史记录

### notification:* - 通知频道
- 短期通知
- 较小的历史记录

## 性能调优建议

### Redis 配置
```yaml
engine:
  redis:
    # 连接池大小
    pool_size: 256
    # 最小空闲连接
    min_idle_conns: 10
    # 连接超时
    dial_timeout: "5s"
    # 读写超时
    read_timeout: "3s"
    write_timeout: "3s"
```

### 连接限制
```yaml
client:
  # 每个节点最大连接数
  connection_limit: 10000
  # 每秒新连接速率
  connection_rate_limit: 100
  # 单用户最大连接数
  user_connection_limit: 10
```

## 监控指标

访问 Prometheus metrics：
```
http://localhost:8500/metrics
```

关键指标：
- `centrifugo_node_num_clients` - 当前连接数
- `centrifugo_node_num_channels` - 活跃频道数
- `centrifugo_node_num_users` - 在线用户数
- `centrifugo_transport_messages_sent` - 发送消息数
- `centrifugo_transport_messages_received` - 接收消息数

## 健康检查

```bash
# 健康检查
curl http://localhost:8500/health

# 返回 200 表示健康
```

## 管理后台

访问：`https://push.yourdomain.com/admin/`

生产环境建议：
- 使用强密码
- 通过防火墙限制访问
- 或完全禁用管理后台

## 负载均衡配置

### Nginx 示例
```nginx
upstream centrifugo {
    ip_hash;  # WebSocket 需要会话保持
    server centrifugo1:8000;
    server centrifugo2:8000;
    server centrifugo3:8000;
}

server {
    listen 443 ssl http2;
    server_name push.yourdomain.com;
    
    location / {
        proxy_pass http://centrifugo;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Caddy 示例
```caddyfile
push.yourdomain.com {
    reverse_proxy centrifugo1:8000 centrifugo2:8000 centrifugo3:8000 {
        lb_policy ip_hash
        header_up X-Real-IP {remote_host}
    }
}
```

## 故障排查

### 连接失败
1. 检查 CORS 配置
2. 检查 JWT token 是否有效
3. 查看 Centrifugo 日志

### 性能问题
1. 检查 Redis 性能
2. 增加 Centrifugo 节点
3. 调整连接限制
4. 优化历史记录配置

### 消息丢失
1. 检查 `force_recovery` 配置
2. 增加 `history_size`
3. 延长 `history_ttl`

## 参考文档

- [官方文档](https://centrifugal.dev/docs/server/configuration)
- [JWT 认证](https://centrifugal.dev/docs/server/authentication)
- [引擎和扩展](https://centrifugal.dev/docs/server/engines)
- [性能调优](https://centrifugal.dev/docs/server/performance)
