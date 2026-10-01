# ==============================================================================
# ClickHouse 26.8 轻量低内存与高稳定性定制镜像
# ==============================================================================
FROM clickhouse/clickhouse-server:26.9

# 复制服务端底层调优与内存硬限制配置 (config.d)
COPY ./config.d/low_mem_tuning.xml /etc/clickhouse-server/config.d/

# 复制用户查询配额、Spill-to-Disk 与异步写入限制配置 (users.d)
COPY ./users.d/resource_limits.xml /etc/clickhouse-server/users.d/

# 设置运行默认时区
ENV TZ=Asia/Shanghai

# 暴露 HTTP (8123) 与原生 TCP (9000) 服务端口
EXPOSE 8123 9000
