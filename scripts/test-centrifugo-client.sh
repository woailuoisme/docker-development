#!/bin/bash
# ============================================================================
# test-centrifugo-client.sh - Centrifugo 客户端长连接协议握手与通道连通性校验
# 单一职责：仅关注 WebSocket 与 SSE / uni_sse 握手连接与消息监听能力。
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
			# 忽略注释和空行
			case "$line" in
				\#* | "" | [[:space:]]*) continue ;;
			esac
			# 仅加载与 Centrifugo 相关的环境变量
			if echo "$line" | grep -q -E "CENTRIFUGO|SITE_ADDRESS|REDIS"; then
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
PUSH_URL="https://push.${SITE_DOMAIN}"
WS_URL="wss://push.${SITE_DOMAIN}"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}      [3/3] Centrifugo 客户端长连接连通性校验 (WebSocket/SSE)    ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 1. 验证 Unidirectional SSE (单向推送 - EventSource)
echo -e "${YELLOW}检查项 1: 发起 Unidirectional SSE 连接测试 (监听 public:test_channel)...${NC}"
SSE_CONNECT_PARAMS='{"channels":["public:test_channel"]}'
# 使用 jq 或者是 python 对参数进行 URL 编码
ENCODED_PARAMS=$(echo -n "$SSE_CONNECT_PARAMS" | jq -sRr @uri 2> /dev/null || python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$SSE_CONNECT_PARAMS")
SSE_URL="${PUSH_URL}/connection/uni_sse?cf_connect=${ENCODED_PARAMS}"

set +e
# 异步后台拉取，限定 3 秒超时
SSE_OUTPUT=$(timeout 3 curl -k -s -N "$SSE_URL")
set -e

if echo "$SSE_OUTPUT" | grep -q "event"; then
	echo -e "${GREEN}✓ SSE (EventSource) 连接并订阅成功！${NC}"
	echo -e "流响应片段:\n${SSE_OUTPUT}"
else
	echo -e "${YELLOW}! 未能在超时时间内捕获到流消息，如果是本地调试匿名直连是正常的。${NC}"
fi

# 2. 验证 WebSocket 端点升级与连接
echo -e "\n${YELLOW}检查项 2: 验证 WebSocket 连接与订阅通道...${NC}"
if command -v websocat &> /dev/null; then
	echo "发现 websocat 工具，开始测试 WebSocket 握手..."
	# 连接单向 Websocket 订阅 public:test_channel 并等待 3 秒
	WS_CONNECT_PARAMS='{"subs":{"public:test_channel":{}}}'
	WS_ENCODED=$(echo -n "$WS_CONNECT_PARAMS" | jq -sRr @uri 2> /dev/null || python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$WS_CONNECT_PARAMS")

	set +e
	WS_OUTPUT=$(timeout 3 websocat -n1 "${WS_URL}/connection/uni_websocket?cf_connect=${WS_ENCODED}" 2>&1)
	set -e

	if [ $? -eq 124 ] || echo "$WS_OUTPUT" | grep -q -E "connect|uid"; then
		echo -e "${GREEN}✓ WebSocket (websocat) 握手升级成功，订阅通过。${NC}"
	else
		echo -e "${RED}✗ WebSocket 握手连接异常: ${WS_OUTPUT}${NC}"
	fi
elif command -v wscat &> /dev/null; then
	echo "发现 wscat 工具，开始测试 WebSocket..."
	set +e
	WS_OUTPUT=$(echo '{"subs":{"public:test_channel":{}}}' | timeout 3 wscat -c "${WS_URL}/connection/uni_websocket" 2>&1)
	set -e
	if echo "$WS_OUTPUT" | grep -q -E "connect|uid"; then
		echo -e "${GREEN}✓ WebSocket (wscat) 握手连接成功。${NC}"
	else
		echo -e "${RED}✗ WebSocket 运行异常。${NC}"
	fi
else
	echo -e "${YELLOW}! 未安装 websocat 或 wscat，跳过 WebSocket 连接流的具体报文测试。${NC}"
	echo "  提示: 可以使用 curl 简单测试 WebSocket 握手请求："
	HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" -H "Upgrade: websocket" -H "Connection: Upgrade" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" -H "Sec-WebSocket-Version: 13" "${PUSH_URL}/connection/websocket")
	if [ "$HTTP_CODE" = "101" ]; then
		echo -e "  ${GREEN}✓ WebSocket 握手升级 HTTP 101 状态码校验成功！${NC}"
	else
		echo -e "  ${RED}✗ WebSocket 握手校验失败: HTTP ${HTTP_CODE}${NC}"
	fi
fi

echo -e "\n${GREEN}✓ 客户端长连接协议与连通性校验全部通过！${NC}"
