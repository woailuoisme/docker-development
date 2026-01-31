#!/bin/bash
set -e

# 颜色定义
C_R="\033[31m" C_G="\033[32m" C_Y="\033[33m" C_B="\033[34m" C_C="\033[36m" C_1="\033[1m" C_0="\033[0m"

# 日志函数
log_info()    { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_B}[INFO]${C_0} %s\n" "$1"; }
log_success() { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_G}[SUCCESS]${C_0} %s\n" "$1"; }
log_warning() { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_Y}[WARNING]${C_0} %s\n" "$1"; }
log_error()   { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_R}[ERROR]${C_0} %s\n" "$1"; }

# --- Configuration ---
REQUIRED_PLUGINS=(
    "redis-cache"          # Redis 对象缓存，提升网站性能
    "query-monitor"        # 开发者调试工具 (监控数据库查询、PHP 错误等)
    "user-switching"       # 快速切换用户身份 (方便测试不同角色权限)
    "ewww-image-optimizer" # 图片自动压缩优化
    "seo-by-rank-math"     # Rank Math SEO 搜索引擎优化插件
    "blocksy-companion"    # Blocksy 主题配套插件 (提供额外小工具和扩展)
    "akismet"              # 反垃圾评论，建议保留
    "hello-dolly"          # Hello Dolly，系统默认插件，建议保留 (slug: hello-dolly, installed: hello)
)

REQUIRED_THEMES=(
    "generatepress"
    "twentytwentyfive"  # 官方默认主题
    "twentytwentyfour"  # 官方默认主题
    "twentytwentythree" # 官方默认主题
)

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
else
    # --- Functions ---
    
    configure_redis() {
        if wp plugin is-active redis-cache --allow-root; then
            log_info "Configuring Redis Object Cache..."
            
            if [ ! -z "$WORDPRESS_REDIS_HOST" ]; then
                wp config set WP_REDIS_HOST "$WORDPRESS_REDIS_HOST" --allow-root --type=constant
            fi
            
            if [ ! -z "$WORDPRESS_REDIS_PORT" ]; then
                wp config set WP_REDIS_PORT "$WORDPRESS_REDIS_PORT" --allow-root --type=constant
            fi
            
            if [ ! -z "$WORDPRESS_REDIS_PASSWORD" ]; then
                wp config set WP_REDIS_PASSWORD "$WORDPRESS_REDIS_PASSWORD" --allow-root --type=constant
            fi
            
            wp redis enable --allow-root || log_warning "Failed to enable redis object cache"
        fi
    }

    sync_extensions() {
        log_info "Syncing plugins and themes..."

        # --- Plugins ---
        log_info "Fetching installed plugins..."
        local installed_plugins=$(wp plugin list --field=name --allow-root)
        
        # 1. Install/Update Required Plugins
        for plugin in "${REQUIRED_PLUGINS[@]}"; do
            # Check if installed
            local is_installed=false
            for inst in $installed_plugins; do
                if [ "$inst" == "$plugin" ]; then
                    is_installed=true
                    break
                fi
                # Special case for hello-dolly (slug: hello-dolly, installed name: hello)
                if [ "$plugin" == "hello-dolly" ] && [ "$inst" == "hello" ]; then
                    is_installed=true
                    break
                fi
            done

            if [ "$is_installed" = true ]; then
                log_info "Updating plugin: $plugin..."
                wp plugin update "$plugin" --allow-root || log_warning "Failed to update $plugin"
            else
                log_info "Installing plugin: $plugin..."
                wp plugin install "$plugin" --allow-root || log_warning "Failed to install $plugin"
            fi
            # Always try to activate
            wp plugin activate "$plugin" --allow-root || log_warning "Failed to activate $plugin"
        done

        # 2. Delete Unwanted Plugins
        # Refresh installed list
        installed_plugins=$(wp plugin list --field=name --allow-root)
        for plugin in $installed_plugins; do
            local keep=false
            for required in "${REQUIRED_PLUGINS[@]}"; do
                if [ "$plugin" == "$required" ]; then
                    keep=true
                    break
                fi
                # Special case for hello-dolly
                if [ "$required" == "hello-dolly" ] && [ "$plugin" == "hello" ]; then
                    keep=true
                    break
                fi
            done
            
            # Don't delete drop-ins or must-use if they appear in this list?
            # 'wp plugin list' shows standard plugins.
            # We might want to keep 'hello' or 'akismet' if user didn't specify them?
            # User said "其他不在列表中的就删除啊". So delete them.
            
            # Skip Drop-ins (files ending in .php in the list)
            if [[ "$plugin" == *".php" ]]; then
                keep=true
            fi

            if [ "$keep" = false ]; then
                log_warning "Deleting unauthorized plugin: $plugin..."
                wp plugin delete "$plugin" --allow-root
            fi
        done

        # --- Themes ---
        log_info "Fetching installed themes..."
        local installed_themes=$(wp theme list --field=name --allow-root)
        
        # 1. Install/Update Required Themes
        for theme in "${REQUIRED_THEMES[@]}"; do
             local is_installed=false
             for inst in $installed_themes; do
                 if [ "$inst" == "$theme" ]; then
                     is_installed=true
                     break
                 fi
             done

             if [ "$is_installed" = true ]; then
                log_info "Updating theme: $theme..."
                wp theme update "$theme" --allow-root
             else
                log_info "Installing theme: $theme..."
                wp theme install "$theme" --allow-root
             fi
             wp theme activate "$theme" --allow-root
        done
        
        # 2. Delete Unwanted Themes
        installed_themes=$(wp theme list --field=name --allow-root)
        for theme in $installed_themes; do
             local keep=false
             for required in "${REQUIRED_THEMES[@]}"; do
                if [ "$theme" == "$required" ]; then
                    keep=true
                    break
                fi
             done
             
             if [ "$keep" = false ]; then
                 log_warning "Deleting unauthorized theme: $theme..."
                 # Note: Cannot delete active theme. But we activated required one above.
                 wp theme delete "$theme" --allow-root || log_warning "Failed to delete theme $theme (maybe active?)"
             fi
        done
    }

    # --- Main Logic ---

    INIT_LOCK_FILE="/var/www/html/.wp-init-complete"

    # Check if WordPress is installed
    if wp core is-installed --allow-root > /dev/null 2>&1; then
        if [ -f "$INIT_LOCK_FILE" ]; then
             log_info "Initialization lock file exists. Skipping plugin/theme sync."
        else
             # Installed: Run Sync
             sync_extensions
             configure_redis
             touch "$INIT_LOCK_FILE"
        fi
        
        # Always configure redis constants if missing (fast check)
        # We can run configure_redis here again if we want to ensure config is always up to date
        # But for "Run Once", let's respect the lock file for heavy ops.
        # configure_redis is relatively fast, let's allow it to run if we want config updates?
        # User asked "Can it run only once". So let's skip it too if locked.
    else
        log_info "WordPress is not installed yet."

        # Check for Auto-Install
        if [ ! -z "$WORDPRESS_ADMIN_USER" ] && [ ! -z "$WORDPRESS_ADMIN_PASSWORD" ] && [ ! -z "$WORDPRESS_ADMIN_EMAIL" ] && [ ! -z "$WORDPRESS_URL" ]; then
            log_info "Auto-installing WordPress..."
            
            # Install Language
            if [ ! -z "$WORDPRESS_LOCALE" ]; then
                 log_info "Installing language $WORDPRESS_LOCALE..."
                 wp language core install $WORDPRESS_LOCALE --activate --allow-root || log_warning "Failed to install language $WORDPRESS_LOCALE"
            fi
            
            wp core install \
                --url="$WORDPRESS_URL" \
                --title="${WORDPRESS_TITLE:-WordPress Site}" \
                --admin_user="$WORDPRESS_ADMIN_USER" \
                --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
                --admin_email="$WORDPRESS_ADMIN_EMAIL" \
                --skip-email \
                --allow-root
            
            if [ $? -eq 0 ]; then
                log_success "WordPress auto-installation completed successfully."
                sync_extensions
                configure_redis
                touch "$INIT_LOCK_FILE"
            else
                log_error "WordPress auto-installation failed."
            fi
        else
            log_info "Auto-install variables not set. Waiting for manual installation."
            # In this case, we can't sync extensions because WP is not installed.
            # We could pre-download them, but `wp plugin install` usually wants core files.
            # The docker image has core files, but without DB, `wp plugin list` fails, so `sync_extensions` would fail.
            # So we do nothing until WP is installed.
        fi
    fi

    log_success "Initialization sequence completed."
fi

log_info "--- Init Script Finished ---"
