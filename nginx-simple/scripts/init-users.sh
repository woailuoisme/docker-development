#!/bin/bash
# /usr/local/bin/init-users.sh - 极端简化版 Nginx 用户初始化脚本
CONFIG_FILE="/etc/nginx/auth/users.yml"
PASSWD_FILE="/etc/nginx/auth/.htpasswd"

# 1. 验证基础
[[ ! -f "$CONFIG_FILE" ]] && echo "Error: $CONFIG_FILE not found" && exit 1
mkdir -p "$(dirname "$PASSWD_FILE")"

# 2. 清理并重新生成密码文件
true > "$PASSWD_FILE"

# 3. 解析 YAML 并生成 htpasswd
# 使用 yq 的 eval 循环读取用户名和密码
user_count=$(yq eval '.users | length' "$CONFIG_FILE")

for (( i=0; i<user_count; i++ )); do
    username=$(yq eval ".users[$i].username" "$CONFIG_FILE")
    password=$(yq eval ".users[$i].password" "$CONFIG_FILE")
    
    echo "Processing user: $username"
    # -b 表示命令行提供密码，-d 使用 CRYPT 加密（通用性好）
    htpasswd -b "$PASSWD_FILE" "$username" "$password"
done

# 4. 权限设置
chmod 644 "$PASSWD_FILE"
echo "Success: Initialized $user_count users."
