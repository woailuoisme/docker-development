#!/bin/bash

# Centrifugo 消息发布测试脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 从 .env 读取 API Key
API_KEY=$(grep "CENTRIFUGO_API_KEY" .env | cut -d '=' -f2)

if [ -z "$API_KEY" ]; then
    echo "错误: 未找到 CENTRIFUGO_API_KEY"
    exit 1
fi

echo -e "${GREEN}Centrifugo 消息发布测试${NC}"
echo "API Key: ${API_KEY:0:8}..."
echo ""

# 1. 发布到 public:chat
echo -e "${YELLOW}[1/4]${NC} 发布消息到 public:chat..."
RESPONSE=$(curl -s -X POST https://push-admin.test.local/api/publish \
  -H "Content-Type: application/json" \
  -H "Authorization: apikey $API_KEY" \
  -k \
  -d '{"channel":"public:chat","data":{"message":"Hello from script","user":"test","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}}')

echo "响应: $RESPONSE"

# 2. 发布到 notification:system
echo -e "\n${YELLOW}[2/4]${NC} 发布通知到 notification:system..."
RESPONSE=$(curl -s -X POST https://push-admin.test.local/api/publish \
  -H "Content-Type: application/json" \
  -H "Authorization: apikey $API_KEY" \
  -k \
  -d '{"channel":"notification:system","data":{"title":"系统通知","message":"这是一条测试通知"}}')

echo "响应: $RESPONSE"

# 3. 广播到多个频道
echo -e "\n${YELLOW}[3/4]${NC} 广播消息到多个频道..."
RESPONSE=$(curl -s -X POST https://push-admin.test.local/api/broadcast \
  -H "Content-Type: application/json" \
  -H "Authorization: apikey $API_KEY" \
  -k \
  -d '{"channels":["public:chat","notification:system"],"data":{"type":"broadcast","message":"广播消息"}}')

echo "响应: $RESPONSE"

# 4. 获取频道列表
echo -e "\n${YELLOW}[4/4]${NC} 获取活跃频道列表..."
RESPONSE=$(curl -s -X POST https://push-admin.test.local/api/channels \
  -H "Content-Type: application/json" \
  -H "Authorization: apikey $API_KEY" \
  -k \
  -d '{"pattern":"public:*"}')

echo "响应: $RESPONSE"

echo -e "\n${GREEN}✓ 测试完成！${NC}"
echo ""
echo "提示: 在另一个终端运行以下命令接收消息："
echo "  wscat -c wss://push.test.local/connection/uni_websocket"
echo "  然后发送: {\"subs\":{\"public:chat\":{}}}"
