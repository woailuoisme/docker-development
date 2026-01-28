#!/usr/bin/env bash
# /opt/startup.sh - 简化版 Nginx 启动脚本
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# 1. 初始化用户认证
if [[ -f "/usr/local/bin/init-users.sh" ]]; then
    log "Initializing auth users..."
    /usr/local/bin/init-users.sh || log "Warning: Auth init failed"
fi

# 2. 确保缓存目录权限 (使用 www-data:www-data 适配 Debian 默认组名)
log "Setting permissions for /var/cache/nginx..."
mkdir -p /var/cache/nginx
chown -R www-data:www-data /var/cache/nginx

# 3. 环境变量替换 (只针对 /etc/nginx/templates 下的 .template 文件)
if [[ -d "/etc/nginx/templates" ]]; then
    log "Applying configuration templates..."
    mkdir -p /etc/nginx/sites-available
    # 获取已定义的变量列表以防止 envsubst 意外替换 shell 变量
    DEFINED_ENVS=$(printf '${%s} ' $(env | cut -d= -f1))
    
    find /etc/nginx/templates -type f -name "*.template" | while read -r template; do
        output="/etc/nginx/conf.d/$(basename "${template%.template}").conf"
        log "Subatituting $template to $output"
        envsubst "$DEFINED_ENVS" < "$template" > "$output"
    done
fi

# 4. 启动服务
log "Testing nginx configuration..."
nginx -t

log "Starting nginx..."
exec nginx -g "daemon off;"
