FROM quay.io/minio/minio
LABEL maintainer="seaside <seaside@qq.com>"

# 设置 startup.sh 使用的环境变量默认值
# 注意：MINIO_ROOT_USER 和 MINIO_ROOT_PASSWORD 已在基础镜像中定义
ENV ENABLE_INITIALIZE_BUCKETS = false \
    MINIO_DATA_PATH=/data \
    MINIO_CONSOLE_PORT=9001 \
    MINIO_ENDPOINT=http://localhost:9000 \
    MINIO_BUCKETS="backup:private:备份存储桶,asset:public:资源存储桶,lunchbox:public:午餐盒应用存储桶,temp:public:临时文件存储桶,logs:private:日志存储桶"

# 复制启动脚本
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# 使用启动脚本作为入口点
ENTRYPOINT ["/usr/local/bin/startup.sh"]

EXPOSE 9000 9001

HEALTHCHECK --interval=60s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9000/minio/health/live || exit 1
