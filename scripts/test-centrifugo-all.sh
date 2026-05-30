#!/bin/bash

# ============================================================================
# test-centrifugo-all.sh - Centrifugo 全方位测试验证脚本
# ============================================================================
# 测试项包含：
# 1. 容器运行状态与健康度
# 2. 容器时区设置校验
# 3. Caddy 网关代理连通性 (WebSocket / SSE 等路径)
# 4. /metrics 监控指标端口公网阻断校验（安全防御测试）
# 5. /admin 管理后台外部连通性校验
# 6. HTTP API 鉴权消息推送验证
# 7. Unidirectional SSE (单向推送) 连通性测试
# ============================================================================

set -e

# 颜色控制
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 加载项目环境变量
if [ -f .env ]; then
	export $(grep -v '^#' .env | xargs)
elif [ -f ../.env ]; then
	export $(grep -v '^#' ../.env | xargs)
fi

# 基础信息配置
SITE_DOMAIN=${SITE_ADDRESS:-"test.local"}
PUSH_URL="https://push.${SITE_DOMAIN}"
API_KEY=${CENTRIFUGO_API_KEY}

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}          Centrifugo v6 容器服务与网关全方位测试脚本            ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "测试目标域名: ${PUSH_URL}"
echo -e "API 密钥首段 : ${API_KEY:0:8}..."
echo -e "${BLUE}----------------------------------------------------------------${NC}"

# 1. 检查容器状态
echo -e "${YELLOW}[1/7] 检查 Centrifugo 容器运行状态...${NC}"
if docker ps --format '{{.Names}}' | grep -q "^centrifugo$"; then
	echo -e "${GREEN}✓ Centrifugo 容器正在运行。${NC}"
else
	echo -e "${RED}✗ 错误: Centrifugo 容器未启动。请先运行: docker compose up -d centrifugo${NC}"
	exit 1
fi

# 2. 检查时区设置
echo -e "\n${YELLOW}[2/7] 检查容器时区是否为上海(CST)...${NC}"
CONTAINER_TIME=$(docker exec centrifugo date)
if echo "$CONTAINER_TIME" | grep -q -E "CST|Shanghai"; then
	echo -e "${GREEN}✓ 时区检查通过: ${CONTAINER_TIME}${NC}"
else
	echo -e "${RED}✗ 时区异常: ${CONTAINER_TIME} (期望为 CST/Shanghai)${NC}"
fi

# 3. 检查容器内部健康度
echo -e "\n${YELLOW}[3/7] 检查容器内部健康检查端点...${NC}"
INTERNAL_HEALTH=$(docker exec centrifugo wget -qO- http://localhost:8000/health || echo "FAIL")
if [ "$INTERNAL_HEALTH" = "{}" ] || [ "$INTERNAL_HEALTH" = "OK" ]; then
	echo -e "${GREEN}✓ 容器内部健康检查响应正常 (wget http://localhost:8000/health -> 200)${NC}"
else
	echo -e "${RED}✗ 容器内部健康检查失败。${NC}"
fi

# 4. 测试外部 Caddy 代理健康端点
echo -e "\n${YELLOW}[4/7] 测试 Caddy 代理健康端点连通性...${NC}"
HEALTH_HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${PUSH_URL}/health")
if [ "$HEALTH_HTTP_CODE" = "200" ]; then
	echo -e "${GREEN}✓ 外部健康端点访问成功: ${PUSH_URL}/health (HTTP ${HEALTH_HTTP_CODE})${NC}"
else
	echo -e "${RED}✗ 外部健康端点不可访问: ${PUSH_URL}/health (HTTP ${HEALTH_HTTP_CODE})${NC}"
fi

# 5. 安全拦截测试：/metrics (监控指标)
echo -e "\n${YELLOW}[5/7] 安全拦截测试: 验证 /metrics 是否成功在公网被阻断...${NC}"
METRICS_HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${PUSH_URL}/metrics" || echo "BLOCKED")
if [ "$METRICS_HTTP_CODE" = "000" ] || [ "$METRICS_HTTP_CODE" = "403" ] || [ "$METRICS_HTTP_CODE" = "BLOCKED" ]; then
	echo -e "${GREEN}✓ 安全防御正常: /metrics 已被 Caddy 成功拦截并阻断 (HTTP ${METRICS_HTTP_CODE})${NC}"
else
	echo -e "${RED}⚠ 安全警告: /metrics 接口暴露！(HTTP ${METRICS_HTTP_CODE})${NC}"
fi

# 6. 后台及 API 可访问性测试：/admin
echo -e "\n${YELLOW}[6/7] 验证管理后台 /admin/ 是否放行...${NC}"
ADMIN_HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${PUSH_URL}/admin/")
if [ "$ADMIN_HTTP_CODE" = "200" ]; then
	echo -e "${GREEN}✓ 管理后台放行成功: ${PUSH_URL}/admin/ (HTTP ${ADMIN_HTTP_CODE})${NC}"
else
	echo -e "${RED}✗ 管理后台访问异常: ${PUSH_URL}/admin/ (HTTP ${ADMIN_HTTP_CODE})${NC}"
fi

# 7. 服务端 API 推送测试 (HTTP API)
echo -e "\n${YELLOW}[7/7] 发送 HTTP API 推送测试指令...${NC}"
API_PAYLOAD='{"method":"publish","params":{"channel":"public:test","data":{"message":"Hello from shell test script!","timestamp":"'$(date "+%Y-%m-%d %H:%M:%S")'"}}}'
API_RESPONSE=$(curl -k -s -X POST "${PUSH_URL}/api" \
	-H "Content-Type: application/json" \
	-H "Authorization: apikey ${API_KEY}" \
	-d "${API_PAYLOAD}")

if echo "$API_RESPONSE" | grep -q "result" || echo "$API_RESPONSE" | grep -q -E "ok|{}"; then
	echo -e "${GREEN}✓ 消息成功推送至 Centrifugo API。${NC}"
	echo -e "接口响应: ${API_RESPONSE}"
else
	echo -e "${RED}✗ 消息推送失败。${NC}"
	echo -e "接口响应: ${API_RESPONSE}"
fi

# 8. 单向 SSE (Unidirectional SSE) 握手流测试
echo -e "\n${YELLOW}[可选测试] 尝试发起单向 SSE 连接并接收第一条推送...${NC}"
echo -e "开始拉取单向流 (限时 3 秒)并监听频道 public:test..."
# 使用 cf_connect 携带 channels 订阅进行 GET 请求
SSE_CONNECT_PARAMS='{"channels":["public:test"]}'
SSE_URL="${PUSH_URL}/connection/uni_sse?cf_connect=$(echo -n "$SSE_CONNECT_PARAMS" | jq -sRr @uri 2> /dev/null || python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$SSE_CONNECT_PARAMS")"

# 异步后台拉取并检查输出
set +e
SSE_OUTPUT=$(timeout 3 curl -k -s -N "$SSE_URL")
set -e

if echo "$SSE_OUTPUT" | grep -q "event"; then
	echo -e "${GREEN}✓ SSE (EventSource) 连接并订阅成功！${NC}"
	echo -e "流响应片段:\n${SSE_OUTPUT}"
else
	echo -e "${YELLOW}! 未能在超时时间内捕获到流消息（可能没有活跃消息），请确认浏览器客户端是否就绪。${NC}"
fi

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${GREEN}             所有配置验证和最佳实践检测执行完毕！               ${NC}"
echo -e "${BLUE}================================================================${NC}"
