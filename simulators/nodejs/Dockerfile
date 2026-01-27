FROM node:20-slim

WORKDIR /app

# 安装环境依赖
COPY package*.json ./
RUN npm install --production

# 复制源码
COPY . .

# 环境变量默认值
ENV MQTT_HOST=mosquitto \
    MQTT_PORT=1883 \
    NODE_ENV=production

# 运行模拟器
CMD ["node", "simulator.js"]
