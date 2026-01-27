# 阶段 1: 安装依赖 (使用 Bun 极速安装)
FROM oven/bun:1.3-alpine AS builder
WORKDIR /app

# 复制依赖定义文件
COPY package.json bun.lock ./

# 安装生产环境依赖
RUN bun install --frozen-lockfile --production

# 阶段 2: 最终运行镜像 (使用 Node.js 24-alpine3.23保持轻量)
FROM node:24-alpine3.23 AS runner
WORKDIR /app

# 仅从 builder 阶段拷贝生产环境依赖
COPY --from=builder /app/node_modules ./node_modules
# 复制应用程序源码
COPY . .

# 环境变量默认值
ENV MQTT_HOST=mosquitto \
    MQTT_PORT=1883 \
    MQTT_USERNAME=admin \
    MQTT_PASSWORD=admin123! \
    DEVICE_NO=VM-BJ-001,VM-BJ-002,VM-BJ-003 \
    REPORT_INTERVAL=10000 \
    MQTT_MAX_RECONNECTS=5 \
    NODE_ENV=production

# 使用 Node.js 运行模拟器
CMD ["node", "simulator.js"]
