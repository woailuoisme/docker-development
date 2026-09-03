import os
import time
import json
import random
import logging
import signal
from datetime import datetime
from dotenv import load_dotenv
import paho.mqtt.client as mqtt
from paho.mqtt.properties import Properties
from paho.mqtt.packettypes import PacketTypes

load_dotenv()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class FrozenMealVendingMachine:
    """
    冷链便当自动售货机 MQTT 5.0 完整模拟器
    严格遵循 mqtt_api_doc.md 接口规范
    """
    
    # 错误码定义
    ERROR_CODES = {
        "E101": "货道库存为空",
        "E102": "红外传感器未感应",
        "E103": "电机电流过载",
        "E201": "微波炉功率异常",
        "E202": "微波炉超时",
        "E301": "冷冻温区超温",
        "E401": "GPS信号丢失",
        "E501": "摄像头离线"
    }

    def __init__(self, device_no):
        self.device_no = device_no
        self.host = os.getenv('MQTT_HOST', 'localhost')
        self.port = int(os.getenv('MQTT_PORT', 1883))
        self.firmware = "5.0.1"
        self.hardware = "v3.2"
        
        # 货道库存初始化
        self.meal_channels = {f"M-{i:02d}": 4 for i in range(1, 49)}
        self.sauce_channels = {f"S-{i:02d}": 10 for i in range(1, 6)}
        self.locked_channels = set()
        
        # 微波炉状态
        self.ovens = {
            "OVEN_A": {"status": "idle", "power": 0},
            "OVEN_B": {"status": "idle", "power": 0}
        }
        
        # 传感器状态
        self.freezer_temps = [-18.5, -19.0, -18.2, -18.8]
        self.ambient_temp = 25.0
        self.voltage = 220.5
        self.current = 1.2
        self.uptime = 0
        self.door_closed = True
        self.vibration_g = 0.02
        self.rssi = -65
        self.lat, self.lng = 31.2304, 121.4737
        
        # 指令幂等缓存 (最近100条)
        self.cmd_cache = []
        
        self.is_connected = False
        self.base_topic = f"v1/vm/{self.device_no}"
        
        # MQTT 5.0 客户端
        self.client = mqtt.Client(
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
            client_id=f"VM_{self.device_no}_{random.randint(1000,9999)}",
            protocol=mqtt.MQTTv5
        )
        
        # LWT 遗嘱消息
        self.client.will_set(
            f"{self.base_topic}/status",
            payload=json.dumps({
                "status": "offline",
                "device_no": self.device_no,
                "reason": "unexpected",
                "ts": int(time.time())
            }),
            qos=1,
            retain=True
        )
        
        self.client.on_connect = self.on_connect
        self.client.on_disconnect = self.on_disconnect
        self.client.on_message = self.on_message

    def on_connect(self, client, userdata, flags, rc, properties=None):
        if rc == 0:
            logger.info(f"[CONNECT] {self.device_no} connected via MQTT 5.0")
            self.is_connected = True
            
            # 订阅指令主题 (QoS 2)
            self.client.subscribe(f"{self.base_topic}/commands", qos=2)
            
            # 发布上线状态
            self.publish_status("online")
        else:
            logger.error(f"[ERROR] Connect failed: {rc}")

    def on_disconnect(self, client, userdata, rc, properties=None):
        self.is_connected = False
        logger.warning(f"[DISCONNECT] {self.device_no} disconnected")

    def on_message(self, client, userdata, msg):
        """处理所有指令"""
        try:
            payload = json.loads(msg.payload.decode())
            cmd_id = payload.get("cmd_id")
            action = payload.get("action")
            params = payload.get("params", {})
            
            logger.info(f"[CMD] Received: {action} (cmd_id: {cmd_id})")
            
            # 幂等性检查
            if cmd_id in self.cmd_cache:
                logger.warning(f"[CMD] Duplicate cmd_id: {cmd_id}, skipping")
                self.send_ack(cmd_id, "success", {"note": "duplicate, already executed"})
                return
            
            # 缓存 cmd_id
            self.cmd_cache.append(cmd_id)
            if len(self.cmd_cache) > 100:
                self.cmd_cache.pop(0)
            
            # 路由指令
            if action == "DISPENSE":
                self.handle_dispense(cmd_id, params)
            elif action == "START_VIDEO":
                self.handle_start_video(cmd_id, params)
            elif action == "STOP_VIDEO":
                self.handle_stop_video(cmd_id, params)
            elif action == "REBOOT":
                self.handle_reboot(cmd_id, params)
            elif action == "LOCK_CHANNEL":
                self.handle_lock_channel(cmd_id, params)
            elif action == "UNLOCK_CHANNEL":
                self.handle_unlock_channel(cmd_id, params)
            elif action == "SET_CONFIG":
                self.handle_set_config(cmd_id, params)
            else:
                self.send_ack(cmd_id, "rejected", error={"code": "E000", "message": f"Unknown action: {action}"})
                
        except Exception as e:
            logger.error(f"[ERROR] Command processing failed: {e}")

    # ==================== 指令处理器 ====================
    
    def handle_dispense(self, cmd_id, params):
        """出餐指令处理"""
        start_time = time.time()
        order_id = params.get("order_id", "ORD_UNKNOWN")
        meal_cid = params.get("meal_cid", "M-01")
        sauce_cid = params.get("sauce_cid", "S-01")
        oven_id = params.get("oven_id", "OVEN_A")
        heat_seconds = params.get("heat_seconds", 90)
        
        # 检查货道锁定
        if meal_cid in self.locked_channels:
            self.send_ack(cmd_id, "failed", error={"code": "E103", "message": f"Channel {meal_cid} is locked"})
            return
        
        # 检查库存
        if self.meal_channels.get(meal_cid, 0) <= 0:
            self.send_event("DISPENSE_FAILED", {
                "order_id": order_id,
                "meal_cid": meal_cid,
                "error_code": "E101"
            })
            self.send_ack(cmd_id, "failed", error={"code": "E101", "message": "Channel empty"})
            return
        
        # 模拟卡货 (3%)
        if random.random() < 0.03:
            self.send_event("CHANNEL_JAM", {
                "channel_id": meal_cid,
                "motor_current": round(random.uniform(4.0, 5.0), 2),
                "error_code": "E103",
                "image_url": f"https://oss.example.com/{self.device_no}/jam_{int(time.time())}.jpg"
            })
            self.locked_channels.add(meal_cid)
            self.send_ack(cmd_id, "failed", error={"code": "E103", "message": f"Channel {meal_cid} jammed"})
            return
        
        # 模拟加热失败 (2%)
        if random.random() < 0.02:
            self.send_event("HEATING_FAILURE", {
                "oven_id": oven_id,
                "expected_power": 1100,
                "actual_power": random.randint(10, 50),
                "exhaust_temp": round(22.0 + random.uniform(0, 3), 1)
            })
            self.send_ack(cmd_id, "failed", error={"code": "E201", "message": f"Oven {oven_id} heating failure"})
            return
        
        # 扣减库存
        self.meal_channels[meal_cid] -= 1
        self.sauce_channels[sauce_cid] = max(0, self.sauce_channels.get(sauce_cid, 0) - 1)
        
        # 发送成功事件
        self.send_event("DISPENSE_SUCCESS", {
            "order_id": order_id,
            "meal_cid": meal_cid,
            "sauce_cid": sauce_cid,
            "oven_id": oven_id,
            "heat_duration": heat_seconds,
            "image_url": f"https://oss.example.com/{self.device_no}/dispense_{int(time.time())}.jpg"
        })
        
        duration_ms = int((time.time() - start_time) * 1000) + heat_seconds * 1000
        self.send_ack(cmd_id, "success", result={"executed_at": int(time.time()), "duration_ms": duration_ms})

    def handle_start_video(self, cmd_id, params):
        """开启视频流"""
        camera_id = params.get("camera_id", "CAM_TOP")
        stream_url = params.get("stream_url", "")
        duration = params.get("duration", 120)
        
        logger.info(f"[VIDEO] Starting stream for {camera_id} -> {stream_url} ({duration}s)")
        self.send_ack(cmd_id, "success", result={"camera_id": camera_id, "streaming": True})

    def handle_stop_video(self, cmd_id, params):
        """关闭视频流"""
        camera_id = params.get("camera_id", "CAM_TOP")
        logger.info(f"[VIDEO] Stopping stream for {camera_id}")
        self.send_ack(cmd_id, "success", result={"camera_id": camera_id, "streaming": False})

    def handle_reboot(self, cmd_id, params):
        """远程重启"""
        delay = params.get("delay", 0)
        reason = params.get("reason", "remote_command")
        logger.warning(f"[REBOOT] System will reboot in {delay}s, reason: {reason}")
        self.send_ack(cmd_id, "success", result={"scheduled_at": int(time.time()) + delay})

    def handle_lock_channel(self, cmd_id, params):
        """锁定货道"""
        channel_id = params.get("channel_id")
        self.locked_channels.add(channel_id)
        logger.info(f"[CHANNEL] Locked: {channel_id}")
        self.send_ack(cmd_id, "success", result={"channel_id": channel_id, "locked": True})

    def handle_unlock_channel(self, cmd_id, params):
        """解锁货道"""
        channel_id = params.get("channel_id")
        self.locked_channels.discard(channel_id)
        logger.info(f"[CHANNEL] Unlocked: {channel_id}")
        self.send_ack(cmd_id, "success", result={"channel_id": channel_id, "locked": False})

    def handle_set_config(self, cmd_id, params):
        """修改配置"""
        logger.info(f"[CONFIG] Updated: {params}")
        self.send_ack(cmd_id, "success", result={"updated": list(params.keys())})

    # ==================== 消息发布 ====================

    def send_event(self, event_type, data):
        """发送事件到 events 主题"""
        props = Properties(PacketTypes.PUBLISH)
        props.ContentType = "application/json"
        props.UserProperty = ("priority", "high" if "FAIL" in event_type or "JAM" in event_type else "normal")
        
        payload = {
            "event_type": event_type,
            "data": data,
            "ts": int(time.time())
        }
        self.client.publish(f"{self.base_topic}/events", json.dumps(payload), qos=1, properties=props)
        logger.info(f"[EVENT] {event_type}")

    def send_ack(self, cmd_id, status, result=None, error=None):
        """发送指令响应到 commands/ack 主题"""
        payload = {
            "cmd_id": cmd_id,
            "status": status,
            "result": result,
            "error": error
        }
        self.client.publish(f"{self.base_topic}/commands/ack", json.dumps(payload), qos=1)
        logger.info(f"[ACK] {cmd_id} -> {status}")

    def publish_status(self, status):
        """发布在线/离线状态"""
        payload = {
            "status": status,
            "device_no": self.device_no,
            "firmware": self.firmware,
            "hardware": self.hardware,
            "ts": int(time.time())
        }
        self.client.publish(f"{self.base_topic}/status", json.dumps(payload), qos=1, retain=True)

    def run_telemetry(self):
        """定时上报遥测数据"""
        if not self.is_connected:
            return
        
        self.uptime += 10
        self.rssi = max(-110, min(-40, self.rssi + random.randint(-2, 2)))
        
        # 模拟温度波动
        self.freezer_temps = [round(t + random.uniform(-0.1, 0.1), 2) for t in self.freezer_temps]
        self.ambient_temp = round(25.0 + random.uniform(-1, 2), 1)
        self.vibration_g = round(random.uniform(0.01, 0.05), 3)
        
        # 模拟超温事件 (1%)
        if random.random() < 0.01:
            self.freezer_temps[random.randint(0, 3)] = -8.0
            self.send_event("TEMP_OVERHEAT", {
                "zone_index": random.randint(0, 3),
                "temperature": -8.0,
                "threshold": -10.0
            })
        
        # 模拟暴力摇晃 (0.5%)
        if random.random() < 0.005:
            g_force = round(random.uniform(2.5, 5.0), 2)
            self.send_event("VANDALISM_ALERT", {
                "g_force": g_force,
                "image_url": f"https://oss.example.com/{self.device_no}/alert_{int(time.time())}.jpg",
                "video_url": f"https://oss.example.com/{self.device_no}/alert_{int(time.time())}.mp4"
            })
        
        # 模拟门打开 (0.5%)
        if random.random() < 0.005:
            self.door_closed = False
            self.send_event("DOOR_OPENED", {
                "door_id": "MAIN",
                "timestamp": int(time.time())
            })
        else:
            self.door_closed = True
        
        payload = {
            "device_no": self.device_no,
            "ts": datetime.utcnow().isoformat() + 'Z',
            "system": {
                "voltage": round(self.voltage + random.uniform(-0.5, 0.5), 1),
                "current": round(self.current + random.uniform(-0.2, 0.2), 2),
                "uptime": self.uptime,
                "door_closed": self.door_closed
            },
            "environment": {
                "freezer_temps": self.freezer_temps,
                "ambient_temp": self.ambient_temp,
                "vibration_g": self.vibration_g
            },
            "connectivity": {
                "rssi": self.rssi,
                "type": "4G",
                "csq": int((self.rssi + 113) / 2)
            },
            "location": {
                "lat": round(self.lat + random.uniform(-0.00005, 0.00005), 6),
                "lng": round(self.lng + random.uniform(-0.00005, 0.00005), 6)
            }
        }
        
        props = Properties(PacketTypes.PUBLISH)
        props.ContentType = "application/json"
        props.UserProperty = ("priority", "low")
        
        self.client.publish(f"{self.base_topic}/telemetry", json.dumps(payload), qos=0, properties=props)
        logger.info(f"[TELEMETRY] Sent")

    def connect(self):
        self.client.connect_async(self.host, self.port, keepalive=60)
        self.client.loop_start()

    def disconnect(self):
        self.publish_status("offline")
        self.client.loop_stop()
        self.client.disconnect()


if __name__ == "__main__":
    device_no = os.getenv('DEVICE_NO', 'VM-SH-001')
    report_interval = int(os.getenv('REPORT_INTERVAL', 10))
    
    vm = FrozenMealVendingMachine(device_no)
    vm.connect()
    
    def signal_handler(sig, frame):
        logger.info("Shutting down...")
        vm.disconnect()
        os._exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info(f"Simulator started for {vm.device_no}")
    while True:
        vm.run_telemetry()
        time.sleep(report_interval)
