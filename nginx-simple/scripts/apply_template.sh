#!/bin/bash

# Nginx 模板生成脚本 - 模拟 Caddy 的模板导出功能
# 用法: 在 templates/apply 中定义 import 语句

TEMPLATE_DIR="/etc/nginx/templates"
OUTPUT_DIR="/etc/nginx/sites-available"
APPLY_FILE="/etc/nginx/apply"

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

# 清理旧的自动生成配置（可选，视具体需求而定）
# rm -rf "${OUTPUT_DIR}"/*.conf

if [[ ! -f "$APPLY_FILE" ]]; then
    echo "No apply file found at $APPLY_FILE"
    exit 0
fi

echo "Start generating Nginx configurations from templates..."

while IFS= read -r line || [[ -n "$line" ]]; do
    # 去除首尾空格
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # 忽略注释 (# 开头) 和空行
    [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] && continue

    # 解析行: import <template_name> <arg1> <arg2> <arg3> ...
    if [[ "$line" =~ ^import[[:space:]]+([^[:space:]]+)(.*)$ ]]; then
        template_name="${BASH_REMATCH[1]}"
        args_str="${BASH_REMATCH[2]}"
        
        # 将参数转换为数组
        read -ra args <<< "$args_str"
        
        template_file="${TEMPLATE_DIR}/${template_name}.conf"
        
        if [[ -f "$template_file" ]]; then
            # 使用域名作为文件名 (通常是第一个参数)
            domain="${args[0]}"
            # 兼容 Caddy 语法: 将 {$VAR} 转换为 ${VAR} 以便 envsubst 处理
            domain=$(echo "$domain" | sed 's/{\$\([^}]\+\)}/${\1}/g' | envsubst)
            output_file="${OUTPUT_DIR}/${domain}.conf"
            
            echo "Applying template '$template_name' to '$domain'..."
            
            # 读取模板内容
            content=$(cat "$template_file")
            
            # 替换占位符 $1, $2, $3 ...
            for i in "${!args[@]}"; do
                placeholder="\$$(($i + 1))"
                # 同时处理参数中的 {$VAR}
                value=$(echo "${args[$i]}" | sed 's/{\$\([^}]\+\)}/${\1}/g' | envsubst)
                # 使用 | 作为 sed 分隔符以处理路径中的 /
                content=$(echo "$content" | sed "s|${placeholder}|${value}|g")
            done
            
            # 最后处理一次模板中可能存在的 {$VAR} 或 ${VAR}
            echo "$content" | sed 's/{\$\([^}]\+\)}/${\1}/g' | envsubst > "$output_file"
        else
            echo "Error: Template '$template_name' not found at $template_file"
        fi
    fi
done < "$APPLY_FILE"

echo "Configuration generation completed."
