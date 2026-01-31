#!/bin/bash
set -e

# 颜色定义
C_R="\033[31m" C_G="\033[32m" C_Y="\033[33m" C_B="\033[34m" C_C="\033[36m" C_1="\033[1m" C_0="\033[0m"

# 日志函数
log_info()    { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_B}[INFO]${C_0} %s\n" "$1"; }
log_success() { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_G}[SUCCESS]${C_0} %s\n" "$1"; }
log_warning() { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_Y}[WARNING]${C_0} %s\n" "$1"; }
log_error()   { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_R}[ERROR]${C_0} %s\n" "$1"; }

log_info "--- Init Script Started ---"

# 等待 MySQL 准备好
max_retries=3
count=0
db_ready=false

log_info "Checking database connection..."

while [ $count -lt $max_retries ]; do
    # 尝试运行 wp 命令，捕获所有输出
    set +e
    output=$(wp core is-installed --allow-root 2>&1)
    exit_code=$?
    set -e
    
    if [ $exit_code -eq 0 ]; then
        log_success "Database connected (WordPress is installed)."
        db_ready=true
        break
    elif [ $exit_code -eq 1 ]; then
        # 检查是否是数据库连接错误
        if echo "$output" | grep -q "Error establishing a database connection"; then
             log_warning "Attempt $count: Database connection failed."
        else
             log_success "Database connected (WordPress not installed)."
             # 忽略 Warning
             db_ready=true
             break
        fi
    else
        log_error "Attempt $count: Unknown error (Exit code $exit_code)."
    fi

    log_info "Waiting for database connection... ($count/$max_retries)"
    sleep 5
    count=$((count+1))
done

if [ "$db_ready" = false ]; then
    log_warning "Database not ready or unreachable after retries. Skipping initialization."
    # 即使失败也不要 exit 1，否则容器会挂掉，导致无限重启
    # 我们只打印警告，然后继续让 php-fpm 启动
else
    # 定义通用函数
    install_plugin() {
        local plugin_slug=$1
        # 检查插件是否存在（通过文件系统检查更可靠，但在 docker 里用 wp-cli 也可以）
        # 忽略 is-installed 的错误，直接尝试安装，如果已存在 wp-cli 会提示
        log_info "Attempting to install $plugin_slug..."
        wp plugin install $plugin_slug --allow-root || log_warning "Failed to install $plugin_slug (WordPress might not be installed yet)"
    }

    # 安装插件文件
    install_plugin redis-cache
    install_plugin query-monitor
    install_plugin user-switching

    # 如果 WordPress 已安装，则激活插件
    if wp core is-installed --allow-root > /dev/null 2>&1; then
        log_info "Activating plugins..."
        wp plugin activate redis-cache query-monitor user-switching --allow-root
        
        if wp plugin is-active redis-cache --allow-root; then
            wp redis enable --allow-root || log_warning "Failed to enable redis object cache"
        fi
    else
        log_info "WordPress is not installed yet. Plugins downloaded but not activated."
    fi

    log_success "Plugin initialization completed."
fi

log_info "--- Init Script Finished ---"
