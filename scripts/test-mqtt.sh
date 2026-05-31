#!/bin/bash
# ============================================================================
# test-mqtt.sh - Mosquitto MQTT Broker 连通性与高可用集成测试 (TCP & WSS)
# 测试范围：
#   1. TCP MQTT 5.0 持久会话 (Session Expiry) + QoS 1 离线消息缓存与重连拉取
#   2. Caddy 反代 WSS (WebSocket Secure) HTTP 101 握手升级验证
# ============================================================================
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 全局清理函数，确保任何异常退出时不残留后台进程
cleanup() {
	local exit_code=$?
	# 清理宿主机后台 docker compose exec 进程
	kill "$(jobs -p)" 2> /dev/null || true
	# 清理可能残留在容器内的订阅客户端进程
	docker compose exec -T mosquitto pkill -9 -f "test_sub_" 2> /dev/null || true
	exit "$exit_code"
}
trap cleanup EXIT

# 加载环境变量：纯 Bash 内置正则匹配，消除 fork 开销
load_env() {
	local env_file="$1"
	if [ -f "$env_file" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			[[ "$line" =~ ^[[:space:]]*# ]] && continue
			[[ -z "${line//[[:space:]]/}" ]] && continue
			if [[ "$line" =~ ^(MQTT_|SITE_ADDRESS=) ]]; then
				local key="${line%%=*}"
				local val="${line#*=}"
				export "$key"="$val"
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
echo -e "${BLUE}      Mosquitto MQTT 5.0 高可用与 Caddy WSS 握手集成测试         ${NC}"
echo -e "${BLUE}================================================================${NC}"

# ============================================================
# 测试 1：TCP MQTT 5.0 持久会话 (Session Expiry) + QoS 1 离线消息
# 验证高可用核心特性：客户端断连后，Broker 为其缓存 QoS 1 消息，
# 重连后自动推送，证明 Broker 具备离线消息持久化能力。
# ============================================================
echo -e "${YELLOW}【测试 1】验证 MQTT 5.0 持久会话与 QoS 1 离线消息缓存/重连拉取...${NC}"

TEST_TOPIC="test/ha/$(date +%s)"
TEST_MSG="HA-offline-message-$(date +%s)"
# Client ID 前缀须与 cleanup 里 pkill 过滤条件一致
CLIENT_ID="test_sub_ha_$(date +%s)"

# 步骤 A：建立持久会话（-c = Clean Start=false，-x 60 = Session Expiry 60s，-q 1 注册 QoS 1 订阅）
# 必须用 -q 1 订阅，Broker 才会为该客户端缓存离线 QoS 1 消息
timeout 5 docker compose exec -T mosquitto mosquitto_sub \
	-h localhost -p 1883 \
	-u "$MQTT_USER" -P "$MQTT_PASS" \
	-t "$TEST_TOPIC" -q 1 \
	-V 5 -i "$CLIENT_ID" -c -x 60 \
	> /dev/null 2>&1 &
sleep 1.5

# 步骤 B：从容器内强杀订阅进程（SIGKILL），模拟客户端突然离线
# SIGKILL 阻止客户端发送含 Session Expiry=0 的 DISCONNECT 报文，从而保留持久会话
docker compose exec -T mosquitto pkill -9 -f "$CLIENT_ID" 2> /dev/null || true
sleep 1.0

# 步骤 C：在客户端离线时发布 QoS 1 消息，Broker 应缓存到该客户端的离线队列
docker compose exec -T mosquitto mosquitto_pub \
	-h localhost -p 1883 \
	-u "$MQTT_USER" -P "$MQTT_PASS" \
	-t "$TEST_TOPIC" -m "$TEST_MSG" -q 1 \
	-V 5 -D publish user-property test_id "ha_integration_$(date +%s)"

# 步骤 D：客户端重连，使用相同 Client ID 恢复持久会话，-C 1 接收 1 条消息后退出
set +e
SUB_RESULT=$(timeout 5 docker compose exec -T mosquitto mosquitto_sub \
	-h localhost -p 1883 \
	-u "$MQTT_USER" -P "$MQTT_PASS" \
	-t "$TEST_TOPIC" -q 1 \
	-V 5 -i "$CLIENT_ID" -c -C 1 2>&1)
set -e

if echo "$SUB_RESULT" | grep -q "$TEST_MSG"; then
	echo -e "${GREEN}✓ MQTT 5.0 持久会话注册、QoS 1 离线缓存与重连拉取验证成功！${NC}"
else
	echo -e "${RED}✗ MQTT 5.0 高可用特性验证失败！${NC}"
	echo -e "  订阅器输出：\n  $SUB_RESULT"
	exit 1
fi

# ============================================================
# 测试 2：Caddy 反代 WSS (WebSocket Secure) HTTP 101 握手
# 强制 --http1.1：Mosquitto 不支持 RFC 8441 (HTTP/2 WebSocket)，
# 默认 HTTP/2 协商会导致 Caddy 502；--max-time 3 防止连接建立后脚本卡死
# ============================================================
echo -e "\n${YELLOW}【测试 2】验证 Caddy 反代 WSS WebSocket 握手 (HTTP 101)...${NC}"

set +e
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
	echo -e "${GREEN}✓ WSS WebSocket HTTP 101 Switching Protocols 握手升级成功！${NC}"
	echo -e "  外部加密 WSS 地址：${BLUE}wss://mqtt.${SITE_DOMAIN}/mqtt${NC}"
else
	echo -e "${RED}✗ WSS 握手验证失败！HTTP 状态码: ${HTTP_CODE}${NC}"
	echo -e "  请检查 Caddy 运行状态及 /etc/caddy/sites/mqtt.conf 配置。"
	exit 1
fi

echo -e "\n${GREEN}✓ 全部测试通过：MQTT 5.0 高可用 (TCP QoS 1) 与 WSS (Caddy) 集成验证完毕！${NC}"
