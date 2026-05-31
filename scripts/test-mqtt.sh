#!/bin/bash
# ============================================================================
# test-mqtt.sh - Mosquitto MQTT Broker 连通性与协议集成测试脚本 (TCP & WSS)
# 单一职责：提供一键式 Native TCP MQTT 5.0 消息流及 Caddy 网关 WSS 握手状态校验。
# ============================================================================
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 加载环境变量
load_env() {
	local env_file="$1"
	if [ -f "$env_file" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			case "$line" in
				\#* | "" | [[:space:]]*) continue ;;
			esac
			if echo "$line" | grep -q -E "MQTT|SITE_ADDRESS"; then
				eval "export $line" 2> /dev/null || true
			fi
		done < "$env_file"
	fi
}

if [ -f .env ]; then
	load_env .env
elif [ -f ../.env ]; then
	load_env ../.env
fi

SITE_DOMAIN=${SITE_ADDRESS:-"test.local"}
MQTT_USER=${MQTT_USERNAME:-"admin"}
MQTT_PASS=${MQTT_PASSWORD:-"admin123!"}
WSS_URL="https://mqtt.${SITE_DOMAIN}"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}      Mosquitto MQTT Broker 连通性集成测试 (TCP & WSS)           ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 1. 验证 Native TCP MQTT 5.0
echo -e "${YELLOW}【测试 1】正在通过容器内置客户端测试 TCP MQTT 5.0 协议...${NC}"

TEST_TOPIC="test/integration/$(date +%s)"
TEST_MSG="Hello MQTT 5.0 from integration script"

# 启动后台订阅进程（使用 -V 5 开启 MQTT 5.0，接收到 1 条消息后立即退出）
set +e
docker compose exec -T mosquitto mosquitto_sub \
	-h localhost \
	-p 1883 \
	-u "$MQTT_USER" \
	-P "$MQTT_PASS" \
	-t "$TEST_TOPIC" \
	-V 5 \
	-C 1 \
	> /tmp/mqtt_test_sub.log 2>&1 &
SUB_PID=$!
set -e

# 等待订阅客户端就绪
sleep 1.5

# 使用 mosquitto_pub 发布消息（使用 -V 5 并携带 MQTT 5.0 特有的 User Properties 属性）
docker compose exec -T mosquitto mosquitto_pub \
	-h localhost \
	-p 1883 \
	-u "$MQTT_USER" \
	-P "$MQTT_PASS" \
	-t "$TEST_TOPIC" \
	-m "$TEST_MSG" \
	-V 5 \
	-D publish user-property test_id "integration_test_123"

# 等待订阅者接收消息并退出
sleep 1.5

SUB_RESULT=$(cat /tmp/mqtt_test_sub.log)
rm -f /tmp/mqtt_test_sub.log

if echo "$SUB_RESULT" | grep -q "$TEST_MSG"; then
	echo -e "${GREEN}✓ Native TCP MQTT 5.0 消息收发与 Properties 属性校验成功！${NC}"
else
	echo -e "${RED}✗ Native TCP MQTT 5.0 校验失败！${NC}"
	echo -e "订阅器输出结果：\n$SUB_RESULT"
	kill $SUB_PID 2> /dev/null || true
	exit 1
fi

# 2. 验证 Caddy 代理的 WSS 握手升级
echo -e "\n${YELLOW}【测试 2】正在通过 Caddy 验证 WSS (WebSocket SSL) 协议握手...${NC}"

# 发送合规的 WebSocket 升级请求，Sec-WebSocket-Protocol 必须声明为 mqtt
set +e
# 显式限制使用 HTTP/1.1，因为 Mosquitto 不支持基于 HTTP/2 的 WebSocket 握手 (RFC 8441)。
# 增加 --max-time 3 以避免 curl 在成功建立 WebSocket 连接后无限期挂起。
HTTP_CODE=$(curl -k -s --http1.1 --max-time 3 -o /dev/null -w "%{http_code}" \
	-H "Upgrade: websocket" \
	-H "Connection: Upgrade" \
	-H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
	-H "Sec-WebSocket-Version: 13" \
	-H "Sec-WebSocket-Protocol: mqtt" \
	--resolve "mqtt.${SITE_DOMAIN}:443:127.0.0.1" \
	"${WSS_URL}/mqtt")
set -e

if [ "$HTTP_CODE" = "101" ]; then
	echo -e "${GREEN}✓ WSS WebSocket HTTP 101 Switching Protocols 握手升级校验成功！${NC}"
	echo -e "  外部加密 WSS 连入地址：${BLUE}wss://mqtt.${SITE_DOMAIN}/mqtt${NC}"
else
	echo -e "${RED}✗ WSS WebSocket 握手验证失败！HTTP 返回状态码: ${HTTP_CODE}${NC}"
	echo -e "  请检查 Caddy 容器运行状态，以及 /etc/caddy/sites/mqtt.conf 配置是否正确。"
	exit 1
fi

echo -e "\n${GREEN}✓ Mosquitto MQTT 5.0 (TCP) 与 WSS (Caddy WebSockets) 集成验证全部通过！${NC}"
