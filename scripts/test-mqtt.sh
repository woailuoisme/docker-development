#!/bin/bash
# ============================================================================
# test-mqtt.sh - Mosquitto MQTT Broker 连通性与高可用集成测试 (TCP & WSS)
#
# 测试 1: TCP MQTT 5.0 持久会话 + QoS 1 离线消息
#   A. mosquitto_sub -q 1 -c -x 60  → 建立持久会话并注册 QoS 1 订阅
#   B. pkill -9 (容器内)             → 模拟客户端突然断线（不发 DISCONNECT）
#   C. mosquitto_pub -q 1            → 发布离线消息，Broker 缓存至队列
#   D. mosquitto_sub -q 1 -C 1       → 重连，自动拉取缓存消息
#
# 测试 2: Caddy WSS 握手
#   curl --http1.1 --max-time 3      → HTTP 101 Switching Protocols
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

# 测试 1: TCP MQTT 5.0 持久会话 + QoS 1 离线消息
echo -e "${YELLOW}【测试 1】TCP MQTT 5.0 持久会话 + QoS 1 离线消息缓存/重连拉取...${NC}"

TEST_TOPIC="test/ha/$(date +%s)"
TEST_MSG="HA-offline-message-$(date +%s)"
# Client ID 前缀须与 cleanup() 里 pkill 过滤条件保持一致
CLIENT_ID="test_sub_ha_$(date +%s)"

# A. mosquitto_sub -q 1 -c -x 60 → 建立持久会话并注册 QoS 1 订阅
# -q 1：让 Broker 知道该订阅需要 QoS 1 缓存，缺省 QoS 0 不会触发离线队列
timeout 5 docker compose exec -T mosquitto mosquitto_sub \
	-h localhost -p 1883 \
	-u "$MQTT_USER" -P "$MQTT_PASS" \
	-t "$TEST_TOPIC" -q 1 \
	-V 5 -i "$CLIENT_ID" -c -x 60 \
	> /dev/null 2>&1 &
sleep 1.5

# B. pkill -9 → 模拟客户端突发断线
# SIGKILL 跳过正常断连握手，Broker 保留持久会话及其 QoS 1 离线队列
docker compose exec -T mosquitto pkill -9 -f "$CLIENT_ID" 2> /dev/null || true
sleep 1.0

# C. mosquitto_pub -q 1 → 发布离线消息，Broker 缓存至该客户端的离线队列
docker compose exec -T mosquitto mosquitto_pub \
	-h localhost -p 1883 \
	-u "$MQTT_USER" -P "$MQTT_PASS" \
	-t "$TEST_TOPIC" -m "$TEST_MSG" -q 1 \
	-V 5 -D publish user-property test_id "ha_integration_$(date +%s)"

# D. mosquitto_sub -q 1 -C 1 → 重连，恢复持久会话，自动拉取离线缓存消息
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

# 测试 2: Caddy WSS 握手
# --http1.1：Mosquitto 不支持 RFC 8441（HTTP/2 WebSocket），默认 HTTP/2 协商会让 Caddy 返回 502
# --max-time 3：WebSocket 升级成功后 TCP 长连接会持续保持，需限时退出
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
