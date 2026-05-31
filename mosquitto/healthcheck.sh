#!/bin/sh
# shellcheck disable=SC2016
# Mosquitto 生产级健康检查脚本
# 支持认证和匿名模式

# 如果设置了用户名和密码，使用认证连入本地
if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
	exec /usr/bin/mosquitto_sub \
		-h localhost \
		-p 1883 \
		-u "$MQTT_USERNAME" \
		-P "$MQTT_PASSWORD" \
		-t '$SYS/broker/uptime' \
		-C 1 \
		> /dev/null 2>&1
else
	# 匿名连接测试
	exec /usr/bin/mosquitto_sub \
		-h localhost \
		-p 1883 \
		-t '$SYS/broker/uptime' \
		-C 1 \
		> /dev/null 2>&1
fi
