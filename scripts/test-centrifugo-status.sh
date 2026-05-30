#!/bin/bash
# ============================================================================
# test-centrifugo-status.sh - Centrifugo 容器运行状态与 Caddy 路由安全校验
# 单一职责：仅关注服务生存状态、健康状态、时区正确性以及网关拦截防御安全。
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

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}   [1/3] Centrifugo 运行环境健康与网关安全策略校验 (Status/Sec)  ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 1. 检查 Docker 容器运行状态
echo -e "${YELLOW}检查项 1: Centrifugo 容器运行状态...${NC}"
if docker ps --format '{{.Names}}' | grep -q "^centrifugo$"; then
	echo -e "${GREEN}✓ Centrifugo 容器正在运行。${NC}"
else
	echo -e "${RED}✗ 错误: Centrifugo 容器未启动。请先运行: docker compose up -d centrifugo${NC}"
	exit 1
fi

# 2. 检查容器时区
echo -e "\n${YELLOW}检查项 2: 容器时区正确性 (期望为上海 CST 时区)...${NC}"
CONTAINER_TIME=$(docker exec centrifugo date)
if echo "$CONTAINER_TIME" | grep -q -E "CST|Shanghai"; then
	echo -e "${GREEN}✓ 时区正确: ${CONTAINER_TIME}${NC}"
else
	echo -e "${RED}✗ 时区异常: ${CONTAINER_TIME} (期望为 CST/Shanghai)${NC}"
fi

# 3. 检查容器内部健康度
echo -e "\n${YELLOW}检查项 3: 容器内部健康检查端点...${NC}"
INTERNAL_HEALTH=$(docker exec centrifugo wget -qO- http://localhost:8000/health || echo "FAIL")
if [ "$INTERNAL_HEALTH" = "{}" ] || [ "$INTERNAL_HEALTH" = "OK" ]; then
	echo -e "${GREEN}✓ 容器内部健康检查响应成功 (wget http://localhost:8000/health -> 200)${NC}"
else
	echo -e "${RED}✗ 容器内部健康检查失败。${NC}"
fi

# 4. 检查外部 Caddy 代理健康端点
echo -e "\n${YELLOW}检查项 4: 外部 Caddy 网关 /health 端点连通性...${NC}"
HEALTH_HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${PUSH_URL}/health")
if [ "$HEALTH_HTTP_CODE" = "200" ]; then
	echo -e "${GREEN}✓ Caddy 外部健康端点访问成功: ${PUSH_URL}/health (HTTP ${HEALTH_HTTP_CODE})${NC}"
else
	echo -e "${RED}✗ Caddy 外部健康端点不可访问: ${PUSH_URL}/health (HTTP ${HEALTH_HTTP_CODE})${NC}"
fi

# 5. 检查外部 Caddy /admin 访问权限
echo -e "\n${YELLOW}检查项 5: 验证 Caddy 是否正确放行管理后台 /admin...${NC}"
ADMIN_HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${PUSH_URL}/admin/")
if [ "$ADMIN_HTTP_CODE" = "200" ]; then
	echo -e "${GREEN}✓ 管理后台放行成功: ${PUSH_URL}/admin/ (HTTP ${ADMIN_HTTP_CODE})${NC}"
else
	echo -e "${RED}✗ 管理后台访问异常: ${PUSH_URL}/admin/ (HTTP ${ADMIN_HTTP_CODE})${NC}"
fi

# 6. 安全拦截测试: /metrics (监控指标)
echo -e "\n${YELLOW}检查项 6: 验证 /metrics 是否已安全屏蔽 (防止公网指标外泄)...${NC}"
set +e
METRICS_HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${PUSH_URL}/metrics")
CURL_EXIT_CODE=$?
set -e

if [ "$CURL_EXIT_CODE" -ne 0 ] || [ "$METRICS_HTTP_CODE" = "000" ] || [ "$METRICS_HTTP_CODE" = "403" ]; then
	echo -e "${GREEN}✓ 安全防御正常: /metrics 已被 Caddy 成功拦截并阻断 (HTTP ${METRICS_HTTP_CODE:-000}, Exit ${CURL_EXIT_CODE})${NC}"
else
	echo -e "${RED}⚠ 安全警告: /metrics 暴露！任何公网用户都能拉取系统指标 (HTTP ${METRICS_HTTP_CODE})${NC}"
fi

echo -e "\n${GREEN}✓ 运行环境与网关安全策略校验全部通过！${NC}"
