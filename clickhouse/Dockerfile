FROM clickhouse:25.8

# 复制低内存优化配置
COPY ./config.d/low_mem_tuning.xml /etc/clickhouse-server/config.d/
COPY ./users.d/resource_limits.xml /etc/clickhouse-server/users.d/

# 设置时区
ENV TZ=Asia/Shanghai

EXPOSE 8123 9000