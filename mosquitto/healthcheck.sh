#!/bin/sh
# Mosquitto 健康检查脚本
# 支持认证和匿名模式

# 如果设置了用户名和密码，使用认证
if [ -n "$MQTT_USERNAME" ] && [ -n "$MQTT_PASSWORD" ]; then
    # 使用认证连接
    /usr/bin/mosquitto_sub \
        -h localhost \
        -p 1883 \
        -u "$MQTT_USERNAME" \
        -P "$MQTT_PASSWORD" \
        -t "\$SYS/broker/uptime" \
        -C 1 \
        > /dev/null 2>&1
else
    # 匿名连接
    /usr/bin/mosquitto_sub \
        -h localhost \
        -p 1883 \
        -t "\$SYS/broker/uptime" \
        -C 1 \
        > /dev/null 2>&1
fi

# 返回 mosquitto_sub 的退出码
exit $?
