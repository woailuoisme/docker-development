#!/bin/sh
# shellcheck disable=SC2016
# Mosquitto 生产级健康检查脚本
# 支持认证和匿名模式

# 优先使用主账号；未配置主账号但配置了多用户时，取第一个账号探测
if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
	exec /usr/bin/mosquitto_sub \
		-h localhost \
		-p 1883 \
		-u "$MQTT_USERNAME" \
		-P "$MQTT_PASSWORD" \
		-t '$SYS/broker/uptime' \
		-C 1 \
		> /dev/null 2>&1
elif [ -n "$MQTT_USERS" ]; then
	# 多用户模式（格式：u1:p1,u2:p2），取第一个账号进行认证探测
	first="${MQTT_USERS%%,*}"
	exec /usr/bin/mosquitto_sub \
		-h localhost \
		-p 1883 \
		-u "${first%%:*}" \
		-P "${first#*:}" \
		-t '$SYS/broker/uptime' \
		-C 1 \
		> /dev/null 2>&1
fi

# 匿名连接测试
exec /usr/bin/mosquitto_sub \
	-h localhost \
	-p 1883 \
	-t '$SYS/broker/uptime' \
	-C 1 \
	> /dev/null 2>&1
