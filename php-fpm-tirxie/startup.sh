#!/bin/bash

# PHP-FPM 启动脚本
set -e

# 日志工具
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
log() { echo -e "${1}[$(date '+%Y-%m-%d %H:%M:%S %z')] [${2}]${NC} ${3}"; }
log_info()    { log "${BLUE}" "INFO" "$1"; }
log_success() { log "${GREEN}" "SUCCESS" "$1"; }
log_warning() { log "${YELLOW}" "WARNING" "$1"; }
log_error()   { log "${RED}" "ERROR" "$1"; }

# 变量
readonly APP_PATH=${APP_PATH:-/var/www/lunchbox}
readonly APP_ENV=${APP_ENV:-docker}

# 1. 环境准备
setup_environment() {
    log_info "正在设置环境..."
    
    # 确保日志目录权限
    mkdir -p /var/log/php-fpm
    chown -R www-data:www-data /var/log/php-fpm
    
    # 设置 SSH 目录权限（仅在可写时执行，处理 :ro 挂载）
    if [ -d "/home/www-data/.ssh" ] && [ -w "/home/www-data/.ssh" ]; then
        log_info "设置 SSH 目录权限..."
        chown -R www-data:www-data /home/www-data/.ssh
        chmod 700 /home/www-data/.ssh
        [ -f "/home/www-data/.ssh/known_hosts" ] && chmod 644 /home/www-data/.ssh/known_hosts
    fi
    
    log_success "环境准备完成"
}

# 2. 启动 PHP-FPM
start_fpm() {
    log_info "启动 PHP-FPM..."
    # 切换到应用目录
    cd "${APP_PATH}"
    exec php-fpm --nodaemonize
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止 FPM..."; exit 0' SIGTERM SIGINT

# 主流程
log_info "PHP-FPM 服务启动序列开始..."
setup_environment
start_fpm
