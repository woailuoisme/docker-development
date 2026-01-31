#!/usr/bin/env bash
# /opt/startup.sh - 简化版 Nginx 启动脚本
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# 1. 初始化用户认证
if [[ -f "/usr/local/bin/init-users.sh" ]]; then
    log "Initializing auth users..."
    /usr/local/bin/init-users.sh || log "Warning: Auth init failed"
fi

# 2. 确保缓存目录权限
log "Setting permissions for /var/cache/nginx..."
mkdir -p /var/cache/nginx
chown -R www-data:www-data /var/cache/nginx

# 3. 模板配置生成 (核心 logic)
if [[ -d "/etc/nginx/templates" ]]; then
    log "Applying configuration templates..."
    
    # 3.1 基础环境变量替换 (如全局 nginx.conf.template)
    DEFINED_ENVS=$(printf '${%s} ' $(env | cut -d= -f1))
    find /etc/nginx/templates -type f -name "*.template" | while read -r template; do
        output="/etc/nginx/conf.d/$(basename "${template%.template}").conf"
        log "Substituting $template to $output"
        envsubst "$DEFINED_ENVS" < "$template" > "$output"
    done

    # 3.2 动态导入生成 (模拟 Caddy import 功能)
    if [[ -f "/usr/local/bin/apply_template.sh" ]]; then
        log "Running Caddy-style template engine..."
        /usr/local/bin/apply_template.sh
    fi
fi

# 4. 启动服务
log "Testing nginx configuration..."
nginx -t

log "Starting nginx..."
exec nginx -g "daemon off;"
