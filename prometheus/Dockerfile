FROM prom/prometheus:v3.9.1

# 切换到 root 以便配置
USER root

# 设置时区并创建配置目录
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    mkdir -p /etc/prometheus/rules /etc/prometheus/targets && \
    chown -R nobody:nobody /etc/prometheus

# 复制配置文件
COPY prometheus.yml /etc/prometheus/prometheus.yml

# 切换回非 root 用户
USER nobody

# 暴露端口
EXPOSE 9090

# 启动命令：启用热加载、历史数据保留、高压缩比
ENTRYPOINT [ "/bin/prometheus" ]
CMD [ "--config.file=/etc/prometheus/prometheus.yml", \
      "--storage.tsdb.path=/prometheus", \
      "--web.console.libraries=/usr/share/prometheus/console_libraries", \
      "--web.console.templates=/usr/share/prometheus/consoles", \
      "--web.enable-lifecycle", \
      "--web.enable-admin-api", \
      "--storage.tsdb.retention.time=15d", \
      "--storage.tsdb.min-block-duration=2h", \
      "--storage.tsdb.max-block-duration=2h" ]
