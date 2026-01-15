#!/bin/sh
set -e

# 日志函数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
}

log_info "=========================================="
log_info "Mosquitto MQTT Broker 启动配置验证"
log_info "=========================================="

# 配置验证函数
validate_config() {
    local errors=0
    
    # 检查 MQTT_ALLOW_ANONYMOUS 配置
    if [ -z "$MQTT_ALLOW_ANONYMOUS" ]; then
        log_warning "MQTT_ALLOW_ANONYMOUS 未设置，默认为 false"
        MQTT_ALLOW_ANONYMOUS="false"
    fi
    
    # 如果禁用匿名访问，必须设置用户名和密码
    if [ "$MQTT_ALLOW_ANONYMOUS" = "false" ]; then
        if [ -z "$MQTT_USERNAME" ] || [ -z "$MQTT_PASSWORD" ]; then
            log_error "禁用匿名访问时必须设置 MQTT_USERNAME 和 MQTT_PASSWORD"
            errors=$((errors + 1))
        else
            log_success "认证配置: 用户名/密码认证已启用"
        fi
    else
        log_warning "匿名访问已启用，这可能存在安全风险"
    fi
    
    # 如果有错误，退出
    if [ $errors -gt 0 ]; then
        log_info "=========================================="
        log_error "配置验证失败，发现 $errors 个错误"
        log_info "=========================================="
        exit 1
    fi
    
    log_success "配置验证通过"
    log_info "=========================================="
}

# 执行配置验证
validate_config

# 如果设置了用户名和密码，则生成密码文件
if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
    log_info "正在生成密码文件..."
    # 使用 mosquitto_passwd 创建哈希密码
    touch /mosquitto/config/passwd
    mosquitto_passwd -b /mosquitto/config/passwd "$MQTT_USERNAME" "$MQTT_PASSWORD"
    # 设置正确的文件权限（Mosquitto 要求）
    chmod 0700 /mosquitto/config/passwd
    log_success "密码文件已生成（哈希格式）"
else
    log_info "使用匿名连接模式"
fi

log_info "=========================================="
log_info "启动 Mosquitto MQTT Broker..."
log_info "=========================================="

# 启动 Mosquitto
exec /docker-entrypoint.sh "$@"