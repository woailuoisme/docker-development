#!/bin/bash

# Nginx 安全配置测试脚本
# 用于验证安全规则是否正确工作

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 目标域名（默认使用 localhost，可通过参数指定）
DOMAIN="${1:-http://localhost}"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Nginx 安全配置测试工具${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "测试目标: ${DOMAIN}\n"

# 测试函数
test_request() {
    local test_name="$1"
    local expected_code="$2"
    local url="$3"
    local user_agent="${4:-Mozilla/5.0}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # 发送请求并获取状态码
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" -A "$user_agent" "$url" 2>/dev/null)

    # 检查结果
    if [ "$status_code" == "$expected_code" ]; then
        echo -e "${GREEN}✓${NC} $test_name (期望: $expected_code, 实际: $status_code)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $test_name (期望: $expected_code, 实际: $status_code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 分类测试标题
print_category() {
    echo -e "\n${YELLOW}[测试分类] $1${NC}"
    echo "----------------------------------------"
}

# 1. 测试敏感文件保护
print_category "敏感文件保护"
test_request "阻止 .env 文件访问" "404" "${DOMAIN}/.env"
test_request "阻止 .git 目录访问" "404" "${DOMAIN}/.git/config"
test_request "阻止 .htaccess 访问" "404" "${DOMAIN}/.htaccess"
test_request "阻止 .gitignore 访问" "404" "${DOMAIN}/.gitignore"
test_request "阻止 .DS_Store 访问" "404" "${DOMAIN}/.DS_Store"

# 2. 测试配置文件保护
print_category "配置文件保护"
test_request "阻止 config.yml 访问" "404" "${DOMAIN}/config.yml"
test_request "阻止 database.ini 访问" "404" "${DOMAIN}/database.ini"
test_request "阻止 settings.conf 访问" "404" "${DOMAIN}/settings.conf"

# 3. 测试备份文件保护
print_category "备份文件保护"
test_request "阻止 .bak 文件访问" "404" "${DOMAIN}/index.php.bak"
test_request "阻止 .backup 文件访问" "404" "${DOMAIN}/config.backup"
test_request "阻止 .old 文件访问" "404" "${DOMAIN}/app.old"
test_request "阻止 .swp 文件访问" "404" "${DOMAIN}/.index.swp"

# 4. 测试开发依赖保护
print_category "开发依赖保护"
test_request "阻止 vendor 目录访问" "404" "${DOMAIN}/vendor/autoload.php"
test_request "阻止 node_modules 访问" "404" "${DOMAIN}/node_modules/package.json"
test_request "阻止 composer.json 访问" "404" "${DOMAIN}/composer.json"
test_request "阻止 package.json 访问" "404" "${DOMAIN}/package.json"

# 5. 测试容器配置保护
print_category "容器配置保护"
test_request "阻止 Dockerfile 访问" "404" "${DOMAIN}/Dockerfile"
test_request "阻止 docker-compose.yml 访问" "404" "${DOMAIN}/docker-compose.yml"

# 6. 测试后台管理路径保护
print_category "后台管理路径保护"
test_request "阻止 phpmyadmin 访问" "404" "${DOMAIN}/phpmyadmin/"
test_request "阻止 pma 访问" "404" "${DOMAIN}/pma/"
test_request "阻止 adminer 访问" "404" "${DOMAIN}/adminer/"

# 7. 测试 WordPress 路径保护（如果不是 WP 站点）
print_category "WordPress 路径保护"
test_request "阻止 wp-admin 访问" "404" "${DOMAIN}/wp-admin/"
test_request "阻止 wp-login.php 访问" "404" "${DOMAIN}/wp-login.php"
test_request "阻止 xmlrpc.php 访问" "404" "${DOMAIN}/xmlrpc.php"

# 8. 测试恶意 User-Agent 检测
print_category "恶意 User-Agent 检测"
test_request "阻止 sqlmap" "403" "${DOMAIN}/" "sqlmap/1.0"
test_request "阻止 nikto" "403" "${DOMAIN}/" "nikto"
test_request "阻止 nmap" "403" "${DOMAIN}/" "nmap"
test_request "阻止空 User-Agent" "403" "${DOMAIN}/" ""
test_request "阻止 masscan" "403" "${DOMAIN}/" "masscan/1.0"

# 9. 测试 SQL 注入防护
print_category "SQL 注入防护"
test_request "阻止 UNION SELECT" "403" "${DOMAIN}/?id=1%20union%20select%20*%20from%20users"
test_request "阻止 DROP TABLE" "403" "${DOMAIN}/?id=1;%20drop%20table%20users"
test_request "阻止 INSERT INTO" "403" "${DOMAIN}/?id=1%20insert%20into%20users"
test_request "阻止 DELETE FROM" "403" "${DOMAIN}/?id=1%20delete%20from%20users"

# 10. 测试路径遍历防护
print_category "路径遍历防护"
test_request "阻止 ../../ 遍历" "403" "${DOMAIN}/../../../../etc/passwd"
test_request "阻止 etc/passwd 访问" "403" "${DOMAIN}/../etc/passwd"

# 11. 测试源代码文件保护
print_category "源代码文件保护"
test_request "阻止 .py 文件访问" "404" "${DOMAIN}/app.py"
test_request "阻止 .sh 文件访问" "404" "${DOMAIN}/deploy.sh"
test_request "阻止 .rb 文件访问" "404" "${DOMAIN}/config.rb"

# 12. 测试数据库文件保护
print_category "数据库文件保护"
test_request "阻止 .sql 文件访问" "404" "${DOMAIN}/backup.sql"
test_request "阻止 .sqlite 文件访问" "404" "${DOMAIN}/database.sqlite"
test_request "阻止 .db 文件访问" "404" "${DOMAIN}/data.db"

# 13. 测试 CI/CD 配置保护
print_category "CI/CD 配置保护"
test_request "阻止 .github 访问" "404" "${DOMAIN}/.github/workflows/deploy.yml"
test_request "阻止 .gitlab-ci.yml 访问" "404" "${DOMAIN}/.gitlab-ci.yml"

# 14. 测试正常请求（应该通过）
print_category "正常请求测试"
test_request "允许正常首页访问" "200" "${DOMAIN}/"
test_request "允许正常 User-Agent" "200" "${DOMAIN}/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

# 打印测试结果摘要
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}  测试结果摘要${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "总测试数: ${TOTAL_TESTS}"
echo -e "${GREEN}通过: ${PASSED_TESTS}${NC}"
echo -e "${RED}失败: ${FAILED_TESTS}${NC}"

# 计算通过率
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")
    echo -e "通过率: ${PASS_RATE}%"
fi

# 退出码
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ 所有测试通过！安全配置正常工作。${NC}"
    exit 0
else
    echo -e "\n${RED}✗ 部分测试失败，请检查配置。${NC}"
    exit 1
fi
