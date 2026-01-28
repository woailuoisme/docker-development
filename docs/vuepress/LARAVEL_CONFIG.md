# Laravel Octane/RoadRunner + PgBouncer 配置指南

## 重要：必须配置

### 1. Laravel Database 配置

在 `config/database.php` 中，PostgreSQL 连接必须禁用预编译语句：

```php
'pgsql' => [
    'driver' => 'pgsql',
    'host' => env('DB_HOST', 'pgbouncer'),  // 使用 PgBouncer
    'port' => env('DB_PORT', '6432'),        // PgBouncer 端口
    'database' => env('DB_DATABASE', 'lunchbox'),
    'username' => env('DB_USERNAME', 'postgres'),
    'password' => env('DB_PASSWORD', ''),
    'charset' => 'utf8',
    'prefix' => '',
    'prefix_indexes' => true,
    'search_path' => 'public',
    'sslmode' => 'prefer',
    
    // 关键配置：禁用预编译语句
    'options' => [
        PDO::ATTR_EMULATE_PREPARES => true,
    ],
    'prepare' => false,  // 必须设置为 false
],
```

### 2. .env 配置

```env
DB_CONNECTION=pgsql
DB_HOST=pgbouncer
DB_PORT=6432
DB_DATABASE=lunchbox
DB_USERNAME=postgres
DB_PASSWORD=your_password
```

## PgBouncer 配置说明

### 连接池模式：Transaction Mode

- **pool_mode = transaction**
- 每个事务结束后，连接返回池中
- 不支持跨事务的特性（PREPARE、LISTEN/NOTIFY、WITH HOLD CURSOR）

### 连接数计算

```
max_client_conn = RoadRunner Workers × 每个 Worker 的连接数
```

例如：
- 4 个 RoadRunner workers
- 每个 worker 最多 50 个数据库连接
- max_client_conn = 4 × 50 = 200

### 后端连接池大小

```
default_pool_size = (PostgreSQL max_connections - 保留连接) / 数据库数量
```

例如：
- PostgreSQL max_connections = 100
- 保留 10 个连接给管理
- 1 个数据库
- default_pool_size = (100 - 10) / 1 = 90

建议设置为 25-50，根据实际负载调整。

## 限制和注意事项

### Transaction Mode 不支持的功能

1. **预编译语句（PREPARE/EXECUTE）**
   - 解决：设置 `'prepare' => false`

2. **LISTEN/NOTIFY**
   - 解决：如需要，直连 PostgreSQL

3. **WITH HOLD CURSOR**
   - 解决：避免使用或直连 PostgreSQL

4. **Advisory Locks**
   - 解决：使用 Redis 或直连 PostgreSQL

5. **临时表跨事务**
   - 解决：在单个事务内使用

### 性能优化建议

1. **连接池大小**
   - 不要设置过大，避免 PostgreSQL 连接数耗尽
   - 监控 `SHOW POOLS;` 查看使用情况

2. **超时配置**
   - `query_wait_timeout = 120` - 防止客户端无限等待
   - `server_idle_timeout = 600` - 回收空闲连接
   - `server_lifetime = 3600` - 定期回收连接

3. **健康检查**
   - `server_check_delay = 30` - 每 30 秒检查后端健康
   - `server_check_query = SELECT 1` - 轻量级检查

## 监控和调试

### 连接到 PgBouncer 管理控制台

```bash
docker exec -it pgbouncer psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer
```

### 常用管理命令

```sql
-- 查看连接池状态
SHOW POOLS;

-- 查看客户端连接
SHOW CLIENTS;

-- 查看服务器连接
SHOW SERVERS;

-- 查看统计信息
SHOW STATS;

-- 查看配置
SHOW CONFIG;

-- 重新加载配置（不中断连接）
RELOAD;

-- 暂停所有连接
PAUSE;

-- 恢复连接
RESUME;

-- 优雅关闭
SHUTDOWN;
```

### 性能指标

关注以下指标：
- `cl_waiting` - 等待连接的客户端数（应该接近 0）
- `sv_idle` - 空闲的服务器连接数
- `sv_active` - 活跃的服务器连接数
- `maxwait` - 最大等待时间（应该很低）

## Docker Compose 配置

确保在 `docker-compose.yml` 中添加 PgBouncer 服务：

```yaml
pgbouncer:
  build:
    context: ./pgbouncer
  container_name: pgbouncer
  restart: always
  ports:
    - "6432:6432"
  environment:
    - TZ=Asia/Shanghai
  volumes:
    - ./pgbouncer/pgbouncer.ini:/etc/pgbouncer/pgbouncer.ini:ro
    - ./pgbouncer/userlist.txt:/etc/pgbouncer/userlist.txt:ro
  depends_on:
    postgres:
      condition: service_healthy
  networks:
    - backend
  healthcheck:
    test: ["CMD", "nc", "-z", "127.0.0.1", "6432"]
    interval: 30s
    timeout: 5s
    retries: 3
```

## 故障排查

### 问题：连接被拒绝

检查：
1. PgBouncer 是否运行：`docker ps | grep pgbouncer`
2. 端口是否监听：`docker exec pgbouncer netstat -tlnp | grep 6432`
3. 认证配置是否正确：检查 `userlist.txt`

### 问题：预编译语句错误

确保 Laravel 配置中设置了 `'prepare' => false`

### 问题：连接池耗尽

增加 `default_pool_size` 或优化应用的数据库连接使用

### 问题：性能下降

1. 检查连接池状态：`SHOW POOLS;`
2. 检查等待客户端：`SHOW CLIENTS;`
3. 调整 `default_pool_size` 和 `max_client_conn`

## 参考资料

- [PgBouncer 官方文档](https://www.pgbouncer.org/config.html)
- [Laravel Database 配置](https://laravel.com/docs/database)
- [Laravel Octane 文档](https://laravel.com/docs/octane)
