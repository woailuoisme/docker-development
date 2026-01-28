# PgBouncer 环境变量配置说明

所有配置都通过环境变量设置，在 `docker-compose.yml` 中覆盖默认值。

## PostgreSQL 连接配置

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `POSTGRES_HOST` | `postgres` | PostgreSQL 主机名 |
| `POSTGRES_PORT` | `5432` | PostgreSQL 端口 |
| `POSTGRES_DB` | `lunchbox` | 数据库名称 |

## 连接池配置

| 环境变量 | 默认值 | 说明 | 推荐值 |
|---------|--------|------|--------|
| `MAX_CLIENT_CONN` | `200` | 最大客户端连接数 | RoadRunner workers × 50 |
| `DEFAULT_POOL_SIZE` | `25` | 默认连接池大小 | 25-50 |
| `MIN_POOL_SIZE` | `5` | 最小连接池大小 | 5-10 |
| `RESERVE_POOL_SIZE` | `5` | 保留连接池大小 | 5-10 |
| `MAX_DB_CONNECTIONS` | `50` | 单个数据库最大连接数 | 50-100 |
| `MAX_USER_CONNECTIONS` | `50` | 单个用户最大连接数 | 50-100 |

## 超时配置（秒）

| 环境变量 | 默认值 | 说明 | 推荐值 |
|---------|--------|------|--------|
| `QUERY_WAIT_TIMEOUT` | `120` | 查询等待超时 | 60-300 |
| `SERVER_IDLE_TIMEOUT` | `600` | 服务器空闲超时 | 300-1800 |
| `SERVER_LIFETIME` | `3600` | 服务器生命周期 | 1800-7200 |

## 日志配置

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `LOG_CONNECTIONS` | `1` | 记录连接日志（0=关闭，1=开启）|
| `LOG_DISCONNECTIONS` | `1` | 记录断开日志（0=关闭，1=开启）|
| `VERBOSE` | `0` | 详细日志（0=关闭，1=开启）|

## Docker Compose 配置示例

```yaml
pgbouncer:
  build:
    context: ./pgbouncer
  container_name: pgbouncer
  restart: always
  ports:
    - "6432:6432"
  environment:
    # PostgreSQL 连接
    - POSTGRES_HOST=postgres
    - POSTGRES_PORT=5432
    - POSTGRES_DB=lunchbox
    
    # 连接池配置（根据实际情况调整）
    - MAX_CLIENT_CONN=200
    - DEFAULT_POOL_SIZE=25
    - MIN_POOL_SIZE=5
    - RESERVE_POOL_SIZE=5
    - MAX_DB_CONNECTIONS=50
    - MAX_USER_CONNECTIONS=50
    
    # 超时配置
    - QUERY_WAIT_TIMEOUT=120
    - SERVER_IDLE_TIMEOUT=600
    - SERVER_LIFETIME=3600
    
    # 日志配置（生产环境建议关闭详细日志）
    - LOG_CONNECTIONS=1
    - LOG_DISCONNECTIONS=1
    - VERBOSE=0
    
    - TZ=Asia/Shanghai
  volumes:
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

## 连接数计算公式

### MAX_CLIENT_CONN（最大客户端连接数）

```
MAX_CLIENT_CONN = RoadRunner Workers × 每个 Worker 的数据库连接数
```

**示例：**
- 4 个 RoadRunner workers
- 每个 worker 最多 50 个数据库连接
- `MAX_CLIENT_CONN = 4 × 50 = 200`

### DEFAULT_POOL_SIZE（默认连接池大小）

```
DEFAULT_POOL_SIZE = (PostgreSQL max_connections - 保留连接) / 数据库数量
```

**示例：**
- PostgreSQL `max_connections = 100`
- 保留 10 个连接给管理和监控
- 1 个数据库
- `DEFAULT_POOL_SIZE = (100 - 10) / 1 = 90`

**建议：** 设置为 25-50，根据实际负载调整

## 性能调优建议

### 开发环境

```yaml
environment:
  - MAX_CLIENT_CONN=50
  - DEFAULT_POOL_SIZE=10
  - MIN_POOL_SIZE=2
  - RESERVE_POOL_SIZE=2
  - VERBOSE=1  # 开启详细日志
```

### 生产环境（小型）

```yaml
environment:
  - MAX_CLIENT_CONN=200
  - DEFAULT_POOL_SIZE=25
  - MIN_POOL_SIZE=5
  - RESERVE_POOL_SIZE=5
  - VERBOSE=0  # 关闭详细日志
```

### 生产环境（大型）

```yaml
environment:
  - MAX_CLIENT_CONN=500
  - DEFAULT_POOL_SIZE=50
  - MIN_POOL_SIZE=10
  - RESERVE_POOL_SIZE=10
  - MAX_DB_CONNECTIONS=100
  - VERBOSE=0
```

## 监控指标

启动后，可以通过以下命令查看配置是否生效：

```bash
# 查看启动日志
docker logs pgbouncer

# 连接到 PgBouncer 管理控制台
docker exec -it pgbouncer psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer

# 查看连接池状态
SHOW POOLS;

# 查看配置
SHOW CONFIG;
```

## 故障排查

### 问题：连接池耗尽

**症状：** 客户端等待时间过长，`cl_waiting` 指标很高

**解决：**
1. 增加 `DEFAULT_POOL_SIZE`
2. 增加 `MAX_DB_CONNECTIONS`
3. 优化应用的数据库连接使用

### 问题：PostgreSQL 连接数过多

**症状：** PostgreSQL 报错 "too many connections"

**解决：**
1. 减少 `DEFAULT_POOL_SIZE`
2. 增加 PostgreSQL 的 `max_connections`
3. 检查是否有连接泄漏

### 问题：连接超时

**症状：** 客户端报错 "query_wait_timeout"

**解决：**
1. 增加 `QUERY_WAIT_TIMEOUT`
2. 增加 `DEFAULT_POOL_SIZE`
3. 检查 PostgreSQL 性能

## 参考资料

- [PgBouncer 官方文档](https://www.pgbouncer.org/)
- [PgBouncer 配置参数](https://www.pgbouncer.org/config.html)
- [Laravel Octane 文档](https://laravel.com/docs/octane)
