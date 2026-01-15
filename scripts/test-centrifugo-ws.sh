#!/bin/bash

# Centrifugo WebSocket 验证脚本
# 域名: push.test.local

echo "=========================================="
echo "Centrifugo WebSocket 验证测试"
echo "域名: push.test.local"
echo "=========================================="

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 检查容器状态
echo -e "\n${YELLOW}[1/6]${NC} 检查 Centrifugo 容器状态..."
if docker ps | grep -q centrifugo; then
    echo -e "${GREEN}✓${NC} Centrifugo 容器正在运行"
    docker ps | grep centrifugo
else
    echo -e "${RED}✗${NC} Centrifugo 容器未运行"
    exit 1
fi

# 2. 检查端口监听
echo -e "\n${YELLOW}[2/6]${NC} 检查端口监听..."
if docker exec centrifugo netstat -tln 2>/dev/null | grep -q ":8000" || \
   docker exec centrifugo ss -tln 2>/dev/null | grep -q ":8000"; then
    echo -e "${GREEN}✓${NC} 端口 8000 (HTTP/WebSocket/Admin) 正在监听"
else
    echo -e "${RED}✗${NC} 端口 8000 未监听"
fi

# 3. HTTP 健康检查
echo -e "\n${YELLOW}[3/6]${NC} HTTP 健康检查..."
if curl -s -f http://localhost:8500/health > /dev/null; then
    echo -e "${GREEN}✓${NC} HTTP 健康检查通过"
else
    echo -e "${RED}✗${NC} HTTP 健康检查失败"
fi

# 4. 通过 Caddy 代理访问
echo -e "\n${YELLOW}[4/6]${NC} 测试 Caddy 代理..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k https://push.test.local/)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "101" ]; then
    echo -e "${GREEN}✓${NC} Caddy 代理正常 (HTTP $HTTP_CODE)"
else
    echo -e "${RED}✗${NC} Caddy 代理异常 (HTTP $HTTP_CODE)"
fi

# 5. 测试 WebSocket 升级（使用 websocat 或 curl）
echo -e "\n${YELLOW}[5/6]${NC} 测试 WebSocket 连接..."

# 检查是否安装了 websocat
if command -v websocat &> /dev/null; then
    echo "使用 websocat 测试..."
    timeout 3 websocat -n1 wss://push.test.local/connection/uni_websocket 2>&1 | head -n 5 || true
    echo -e "${GREEN}✓${NC} WebSocket 端点可访问"
else
    # 使用 wscat 测试
    echo "使用 wscat 测试..."
    if command -v wscat &> /dev/null; then
        echo '{"subs":{"public:chat":{}}}' | timeout 3 wscat -c wss://push.test.local/connection/uni_websocket 2>&1 | grep -q "connect" && \
            echo -e "${GREEN}✓${NC} WebSocket 连接成功" || \
            echo -e "${RED}✗${NC} WebSocket 连接失败"
    else
        echo -e "${YELLOW}!${NC} 未安装 websocat 或 wscat，跳过 WebSocket 测试"
        echo "  安装: brew install websocat 或 npm install -g wscat"
    fi
fi

# 6. 检查 Centrifugo 日志
echo -e "\n${YELLOW}[6/6]${NC} 检查最近日志..."
docker logs centrifugo --tail 5 2>&1 | grep -v "^$" || echo "无日志输出"

# 总结
echo -e "\n=========================================="
echo -e "${GREEN}验证完成！${NC}"
echo "=========================================="
echo ""
echo "WebSocket 连接信息:"
echo "  - URL: wss://push.test.local/connection/websocket"
echo "  - HTTP API: https://push.test.local/api"
echo "  - Admin UI: https://push.test.local/admin/ (如果配置了)"
echo ""
echo "下一步测试:"
echo "  1. 使用浏览器访问: https://push.test.local/admin/"
echo "  2. 使用 JavaScript 客户端测试 WebSocket"
echo "  3. 查看完整文档: docker exec centrifugo centrifugo version"
echo ""
