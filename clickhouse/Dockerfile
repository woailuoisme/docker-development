# 推荐版本：LTS 稳定版
FROM clickhouse/clickhouse-server:25.8-jammy

# 1. 拷贝针对低内存优化的配置文件
# 注意：这些 .xml 需要你在本地准备好
COPY ./config.d/low_mem_tuning.xml /etc/clickhouse-server/config.d/
COPY ./users.d/resource_limits.xml /etc/clickhouse-server/users.d/

# 2. 修正时区（可选，方便查看日志）
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 3. 暴露端口
EXPOSE 8123 9000