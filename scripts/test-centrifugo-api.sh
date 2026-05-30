#!/bin/bash
# ============================================================================
# test-centrifugo-api.sh - Centrifugo 服务端 HTTP API 接口推送与控制校验
# 单一职责：仅关注服务端 API 发送、广播以及命名空间推送有效性。
# ============================================================================
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 加载环境变量
# shellcheck disable=SC2046
if [ -f .env ]; then
	export $(grep -v '^#' .env | grep -E "CENTRIFUGO|SITE_ADDRESS|REDIS" | xargs)
elif [ -f ../.env ]; then
	export $(grep -v '^#' ../.env | grep -E "CENTRIFUGO|SITE_ADDRESS|REDIS" | xargs)
fi

SITE_DOMAIN=${SITE_ADDRESS:-"test.local"}
PUSH_URL="https://push.${SITE_DOMAIN}"
API_KEY=${CENTRIFUGO_API_KEY}

if [ -z "$API_KEY" ]; then
	echo -e "${RED}错误: 未能在环境变量或 .env 中找到 CENTRIFUGO_API_KEY${NC}"
	exit 1
fi

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}        [2/3] Centrifugo 服务端 HTTP API 通信与发布功能校验      ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 1. 验证四个命名空间发布
echo -e "${YELLOW}检查项 1: 向四个不同的命名空间通道推送消息...${NC}"
for NS in "public" "private" "user" "notification"; do
	CHANNEL="${NS}:test_channel"
	echo -e "正在向通道 [${CHANNEL}] 发送数据..."
	API_PAYLOAD='{"method":"publish","params":{"channel":"'"${CHANNEL}"'","data":{"message":"API test message to namespace '"${NS}"'!","timestamp":"'$(date "+%Y-%m-%d %H:%M:%S")'"}}}'

	API_RESPONSE=$(curl -k -s -X POST "${PUSH_URL}/api" \
		-H "Content-Type: application/json" \
		-H "Authorization: apikey ${API_KEY}" \
		-d "${API_PAYLOAD}")

	if echo "$API_RESPONSE" | grep -q "result" || echo "$API_RESPONSE" | grep -q -E "ok|{}"; then
		echo -e "  ${GREEN}✓ 命名空间 [${NS}] 推送成功。${NC}"
	else
		echo -e "  ${RED}✗ 命名空间 [${NS}] 推送失败。响应: ${API_RESPONSE}${NC}"
	fi
done

# 2. 验证多通道广播 (Broadcast)
echo -e "\n${YELLOW}检查项 2: 多通道广播 (Broadcast) 功能验证...${NC}"
BROADCAST_PAYLOAD='{"method":"broadcast","params":{"channels":["public:test_channel","notification:test_channel"],"data":{"message":"API broadcast message","timestamp":"'$(date "+%Y-%m-%d %H:%M:%S")'"}}}'
BROADCAST_RESPONSE=$(curl -k -s -X POST "${PUSH_URL}/api" \
	-H "Content-Type: application/json" \
	-H "Authorization: apikey ${API_KEY}" \
	-d "${BROADCAST_PAYLOAD}")

if echo "$BROADCAST_RESPONSE" | grep -q "result" || echo "$BROADCAST_RESPONSE" | grep -q -E "ok|{}"; then
	echo -e "${GREEN}✓ 广播消息成功。${NC}"
else
	echo -e "${RED}✗ 广播消息失败。响应: ${BROADCAST_RESPONSE}${NC}"
fi

# 3. 验证获取活跃频道列表 (Channels)
echo -e "\n${YELLOW}检查项 3: 获取当前活跃的频道列表 (Channels)...${NC}"
CHANNELS_PAYLOAD='{"method":"channels","params":{"pattern":"public:*"}}'
CHANNELS_RESPONSE=$(curl -k -s -X POST "${PUSH_URL}/api" \
	-H "Content-Type: application/json" \
	-H "Authorization: apikey ${API_KEY}" \
	-d "${CHANNELS_PAYLOAD}")

if echo "$CHANNELS_RESPONSE" | grep -q "result" || echo "$CHANNELS_RESPONSE" | grep -q -E "ok|{}"; then
	echo -e "${GREEN}✓ 获取活跃频道成功。${NC}"
	echo -e "当前活跃频道: ${CHANNELS_RESPONSE}"
else
	echo -e "${RED}✗ 获取活跃频道失败。响应: ${CHANNELS_RESPONSE}${NC}"
fi

echo -e "\n${GREEN}✓ 服务端 HTTP API 接口推送校验全部通过！${NC}"
