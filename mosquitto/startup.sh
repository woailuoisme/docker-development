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
log_info "Mosquitto MQTT Broker 启动配置初始化与验证"
log_info "=========================================="

# 1. 检查并处理空挂载目录遮蔽问题
if [ ! -f /mosquitto/config/mosquitto.conf ]; then
	log_warning "未检测到 /mosquitto/config/mosquitto.conf，正在从模板初始化配置..."
	cp /etc/mosquitto.templates/mosquitto.conf /mosquitto/config/mosquitto.conf
	log_success "默认 mosquitto.conf 已复制"
fi

if [ ! -f /mosquitto/config/acl ]; then
	log_info "未检测到 /mosquitto/config/acl，正在初始化默认 of acl 策略..."
	cp /etc/mosquitto.templates/acl /mosquitto/config/acl
	log_success "默认 acl 已复制"
fi

# 确保运行权限
chmod 644 /mosquitto/config/mosquitto.conf
chmod 644 /mosquitto/config/acl

# 2. 配置验证函数
validate_config() {
	local errors=0

	# 检查 MQTT_ALLOW_ANONYMOUS 配置
	if [ -z "$MQTT_ALLOW_ANONYMOUS" ]; then
		log_warning "MQTT_ALLOW_ANONYMOUS 未设置，默认为 false"
		MQTT_ALLOW_ANONYMOUS="false"
	fi

	# 如果禁用匿名访问，必须设置主用户名密码或配置了多用户
	if [ "$MQTT_ALLOW_ANONYMOUS" = "false" ]; then
		if [ -z "$MQTT_USERNAME" ] && [ -z "$MQTT_USERS" ]; then
			log_error "禁用匿名访问时，必须设置主管理员（MQTT_USERNAME）或配置多账户（MQTT_USERS）"
			errors=$((errors + 1))
		else
			log_success "认证配置: 账号密码验证已启用"
		fi
	else
		log_warning "匿名访问已启用，这在生产环境存在极高安全风险"
	fi

	# 如果有错误，退出
	if [ $errors -gt 0 ]; then
		log_info "=========================================="
		log_error "配置验证失败，发现 $errors 个错误"
		log_info "=========================================="
		exit 1
	fi

	log_success "配置验证通过"
}

# 执行配置验证
validate_config

# 3. 创建与生成密码文件
# 初始化空的 passwd 文件
touch /mosquitto/config/passwd
chmod 0600 /mosquitto/config/passwd
# 清空旧数据
true > /mosquitto/config/passwd

# 写入主账号（如果存在）
if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
	log_info "正在生成主管理员账户..."
	mosquitto_passwd -b /mosquitto/config/passwd "$MQTT_USERNAME" "$MQTT_PASSWORD"
	log_success "主管理员账号 $MQTT_USERNAME 写入完成"
fi

# 解析并写入环境变量指定的多用户（格式：u1:p1,u2:p2）
if [ -n "$MQTT_USERS" ]; then
	log_info "正在生成多账户配置..."
	# 将逗号转换成换行以支持安全的循环读取，防止包含空格的复杂密码解析错位
	echo "$MQTT_USERS" | tr ',' '\n' | while read -r user_pair; do
		if [ -n "$user_pair" ]; then
			u=$(echo "$user_pair" | cut -d':' -f1)
			p=$(echo "$user_pair" | cut -d':' -f2-)
			if [ -n "$u" ] && [ -n "$p" ]; then
				mosquitto_passwd -b /mosquitto/config/passwd "$u" "$p"
				log_success "已成功添加用户: $u"
			fi
		fi
	done
fi

log_info "=========================================="
log_info "启动 Mosquitto MQTT Broker..."
log_info "=========================================="

# 启动 Mosquitto（移交控制权给自带入口，自动处理降权逻辑）
exec /docker-entrypoint.sh "$@"
