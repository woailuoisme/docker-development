FROM tecnativa/docker-socket-proxy:v0.4.2

LABEL maintainer="seaside <531773730@qq.com>"

# Docker Socket Proxy 环境变量配置
# 用于安全地暴露 Docker Socket API，限制只读权限

# ============================================
# 基础配置
# ============================================
ENV LOG_LEVEL=info

# ============================================
# 只读权限（推荐用于监控工具）
# ============================================
# EVENTS=1      - 允许监听 Docker 事件流
# PING=1        - 允许 ping 检查（健康检查必需）
# VERSION=1     - 允许查看 Docker 版本信息
ENV EVENTS=1 \
    PING=1 \
    VERSION=1

# ============================================
# 容器和镜像管理（只读）
# ============================================
# CONTAINERS=1  - 允许查看容器列表和状态
# IMAGES=1      - 允许查看镜像列表
# INFO=1        - 允许查看 Docker 系统信息
# NETWORKS=1    - 允许查看网络列表
# VOLUMES=1     - 允许查看卷列表
ENV CONTAINERS=1 \
    IMAGES=1 \
    INFO=1 \
    NETWORKS=1 \
    VOLUMES=1

# ============================================
# Docker Swarm 相关（如果使用 Swarm 集群）
# ============================================
# SERVICES=1    - 允许查看 Swarm 服务
# TASKS=1       - 允许查看 Swarm 任务
# NODES=0       - 禁止查看 Swarm 节点信息
ENV SERVICES=1 \
    TASKS=1 \
    NODES=0

# ============================================
# 写操作权限（安全起见全部禁用）
# ============================================
# POST=0        - 禁止所有 POST 请求（创建、启动、停止等）
# BUILD=0       - 禁止构建镜像
# COMMIT=0      - 禁止提交容器为镜像
# CONFIGS=0     - 禁止配置操作
# DISTRIBUTION=0- 禁止镜像分发操作
# EXEC=0        - 禁止在容器中执行命令
# GRPC=0        - 禁止 gRPC 操作
# SECRETS=0     - 禁止密钥操作
# SESSION=0     - 禁止会话操作
# SWARM=0       - 禁止 Swarm 管理操作
ENV POST=0 \
    BUILD=0 \
    COMMIT=0 \
    CONFIGS=0 \
    DISTRIBUTION=0 \
    EXEC=0 \
    GRPC=0 \
    SECRETS=0 \
    SESSION=0 \
    SWARM=0

# ============================================
# 健康检查
# ============================================
HEALTHCHECK --interval=60s --timeout=5s --retries=3 \
    CMD wget --spider -q http://localhost:2375/_ping || exit 1
