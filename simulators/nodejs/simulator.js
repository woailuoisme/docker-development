const mqtt = require('mqtt');
require('dotenv').config();

/**
 * 冷链便当自动售货机 MQTT 5.0 完整模拟器 (Node.js)
 * 严格遵循 mqtt_api_doc.md 接口规范
 */
class FrozenMealVendingMachine {
    constructor(deviceNo) {
        this.device_no = deviceNo;
        this.host = process.env.MQTT_HOST || 'localhost';
        this.port = process.env.MQTT_PORT || 1883;
        this.firmware = "5.0.1";
        this.hardware = "v3.2";

        this.baseTopic = `v1/vm/${this.device_no}`;
        
        // 货道库存
        this.mealChannels = {};
        for (let i = 1; i <= 48; i++) {
            this.mealChannels[`M-${i.toString().padStart(2, '0')}`] = 4;
        }
        this.sauceChannels = { "S-01": 10, "S-02": 10, "S-03": 10, "S-04": 10, "S-05": 10 };
        this.lockedChannels = new Set();
        
        // 微波炉状态
        this.ovens = {
            "OVEN_A": { status: "idle", power: 0 },
            "OVEN_B": { status: "idle", power: 0 }
        };
        
        // 传感器状态
        this.freezerTemps = [-18.5, -19.0, -18.2, -18.8];
        this.ambientTemp = 25.0;
        this.voltage = 220.5;
        this.current = 1.2;
        this.uptime = 0;
        this.doorClosed = true;
        this.vibrationG = 0.02;
        this.rssi = -65;
        this.location = { lat: 39.9042, lng: 116.4074 };
        
        // 指令幂等缓存
        this.cmdCache = [];

        // MQTT 5.0 连接
        const options = {
            clientId: `VM_${this.device_no}_${Math.random().toString(16).slice(2, 6)}`,
            protocolVersion: 5,
            clean: true,
            will: {
                topic: `${this.baseTopic}/status`,
                payload: JSON.stringify({
                    status: 'offline',
                    device_no: this.device_no,
                    reason: 'unexpected',
                    ts: Math.floor(Date.now() / 1000)
                }),
                qos: 1,
                retain: true
            }
        };

        if (process.env.MQTT_USERNAME) {
            options.username = process.env.MQTT_USERNAME;
            options.password = process.env.MQTT_PASSWORD;
        }

        this.client = mqtt.connect(`mqtt://${this.host}:${this.port}`, options);
        this.setupHandlers();
    }

    setupHandlers() {
        this.client.on('connect', () => {
            console.log(`[CONNECT] ${this.device_no} connected via MQTT 5.0`);
            
            // 订阅指令主题 (QoS 2)
            this.client.subscribe(`${this.baseTopic}/commands`, { qos: 2 });
            
            // 发布上线状态
            this.publishStatus('online');
        });

        this.client.on('message', (topic, message) => {
            this.handleCommand(message);
        });

        this.client.on('error', (err) => {
            console.error(`[ERROR] ${err.message}`);
        });
    }

    handleCommand(message) {
        try {
            const payload = JSON.parse(message.toString());
            const { cmd_id, action, params = {} } = payload;
            
            console.log(`[CMD] Received: ${action} (cmd_id: ${cmd_id})`);
            
            // 幂等性检查
            if (this.cmdCache.includes(cmd_id)) {
                console.log(`[CMD] Duplicate cmd_id: ${cmd_id}, skipping`);
                this.sendAck(cmd_id, 'success', { note: 'duplicate, already executed' });
                return;
            }
            
            this.cmdCache.push(cmd_id);
            if (this.cmdCache.length > 100) this.cmdCache.shift();
            
            // 路由指令
            switch (action) {
                case 'DISPENSE':
                    this.handleDispense(cmd_id, params);
                    break;
                case 'START_VIDEO':
                    this.handleStartVideo(cmd_id, params);
                    break;
                case 'STOP_VIDEO':
                    this.handleStopVideo(cmd_id, params);
                    break;
                case 'REBOOT':
                    this.handleReboot(cmd_id, params);
                    break;
                case 'LOCK_CHANNEL':
                    this.handleLockChannel(cmd_id, params);
                    break;
                case 'UNLOCK_CHANNEL':
                    this.handleUnlockChannel(cmd_id, params);
                    break;
                case 'SET_CONFIG':
                    this.handleSetConfig(cmd_id, params);
                    break;
                default:
                    this.sendAck(cmd_id, 'rejected', null, { code: 'E000', message: `Unknown action: ${action}` });
            }
        } catch (e) {
            console.error(`[ERROR] Command processing failed: ${e.message}`);
        }
    }

    // ==================== 指令处理器 ====================

    handleDispense(cmdId, params) {
        const startTime = Date.now();
        const { order_id = 'ORD_UNKNOWN', meal_cid = 'M-01', sauce_cid = 'S-01', oven_id = 'OVEN_A', heat_seconds = 90 } = params;
        
        // 检查锁定
        if (this.lockedChannels.has(meal_cid)) {
            this.sendAck(cmdId, 'failed', null, { code: 'E103', message: `Channel ${meal_cid} is locked` });
            return;
        }
        
        // 检查库存
        if ((this.mealChannels[meal_cid] || 0) <= 0) {
            this.sendEvent('DISPENSE_FAILED', { order_id, meal_cid, error_code: 'E101' });
            this.sendAck(cmdId, 'failed', null, { code: 'E101', message: 'Channel empty' });
            return;
        }
        
        // 模拟卡货 (3%)
        if (Math.random() < 0.03) {
            this.sendEvent('CHANNEL_JAM', {
                channel_id: meal_cid,
                motor_current: parseFloat((Math.random() + 4).toFixed(2)),
                error_code: 'E103',
                image_url: `https://oss.example.com/${this.device_no}/jam_${Date.now()}.jpg`
            });
            this.lockedChannels.add(meal_cid);
            this.sendAck(cmdId, 'failed', null, { code: 'E103', message: `Channel ${meal_cid} jammed` });
            return;
        }
        
        // 模拟加热失败 (2%)
        if (Math.random() < 0.02) {
            this.sendEvent('HEATING_FAILURE', {
                oven_id,
                expected_power: 1100,
                actual_power: Math.floor(Math.random() * 50) + 10,
                exhaust_temp: parseFloat((22 + Math.random() * 3).toFixed(1))
            });
            this.sendAck(cmdId, 'failed', null, { code: 'E201', message: `Oven ${oven_id} heating failure` });
            return;
        }
        
        // 扣减库存
        this.mealChannels[meal_cid]--;
        this.sauceChannels[sauce_cid] = Math.max(0, (this.sauceChannels[sauce_cid] || 0) - 1);
        
        // 发送成功事件
        this.sendEvent('DISPENSE_SUCCESS', {
            order_id,
            meal_cid,
            sauce_cid,
            oven_id,
            heat_duration: heat_seconds,
            image_url: `https://oss.example.com/${this.device_no}/dispense_${Date.now()}.jpg`
        });
        
        const durationMs = Date.now() - startTime + heat_seconds * 1000;
        this.sendAck(cmdId, 'success', { executed_at: Math.floor(Date.now() / 1000), duration_ms: durationMs });
    }

    handleStartVideo(cmdId, params) {
        const { camera_id = 'CAM_TOP', stream_url = '', duration = 120 } = params;
        console.log(`[VIDEO] Starting stream for ${camera_id} -> ${stream_url} (${duration}s)`);
        this.sendAck(cmdId, 'success', { camera_id, streaming: true });
    }

    handleStopVideo(cmdId, params) {
        const { camera_id = 'CAM_TOP' } = params;
        console.log(`[VIDEO] Stopping stream for ${camera_id}`);
        this.sendAck(cmdId, 'success', { camera_id, streaming: false });
    }

    handleReboot(cmdId, params) {
        const { delay = 0, reason = 'remote_command' } = params;
        console.log(`[REBOOT] System will reboot in ${delay}s, reason: ${reason}`);
        this.sendAck(cmdId, 'success', { scheduled_at: Math.floor(Date.now() / 1000) + delay });
    }

    handleLockChannel(cmdId, params) {
        const { channel_id } = params;
        this.lockedChannels.add(channel_id);
        console.log(`[CHANNEL] Locked: ${channel_id}`);
        this.sendAck(cmdId, 'success', { channel_id, locked: true });
    }

    handleUnlockChannel(cmdId, params) {
        const { channel_id } = params;
        this.lockedChannels.delete(channel_id);
        console.log(`[CHANNEL] Unlocked: ${channel_id}`);
        this.sendAck(cmdId, 'success', { channel_id, locked: false });
    }

    handleSetConfig(cmdId, params) {
        console.log(`[CONFIG] Updated:`, params);
        this.sendAck(cmdId, 'success', { updated: Object.keys(params) });
    }

    // ==================== 消息发布 ====================

    sendEvent(eventType, data) {
        const payload = {
            event_type: eventType,
            data,
            ts: Math.floor(Date.now() / 1000)
        };
        const options = {
            qos: 1,
            properties: {
                contentType: 'application/json',
                userProperties: { priority: eventType.includes('FAIL') || eventType.includes('JAM') ? 'high' : 'normal' }
            }
        };
        this.client.publish(`${this.baseTopic}/events`, JSON.stringify(payload), options);
        console.log(`[EVENT] ${eventType}`);
    }

    sendAck(cmdId, status, result = null, error = null) {
        const payload = { cmd_id: cmdId, status, result, error };
        this.client.publish(`${this.baseTopic}/commands/ack`, JSON.stringify(payload), { qos: 1 });
        console.log(`[ACK] ${cmdId} -> ${status}`);
    }

    publishStatus(status) {
        const payload = {
            status,
            device_no: this.device_no,
            firmware: this.firmware,
            hardware: this.hardware,
            ts: Math.floor(Date.now() / 1000)
        };
        this.client.publish(`${this.baseTopic}/status`, JSON.stringify(payload), { qos: 1, retain: true });
    }

    sendTelemetry() {
        if (!this.client.connected) return;
        
        this.uptime += 10;
        this.rssi = Math.max(-110, Math.min(-40, this.rssi + Math.floor(Math.random() * 5 - 2)));
        
        // 模拟温度波动
        this.freezerTemps = this.freezerTemps.map(t => parseFloat((t + (Math.random() - 0.5) * 0.2).toFixed(2)));
        this.ambientTemp = parseFloat((25 + Math.random() * 2).toFixed(1));
        this.vibrationG = parseFloat((Math.random() * 0.05).toFixed(3));
        
        // 模拟超温事件 (1%)
        if (Math.random() < 0.01) {
            const zoneIndex = Math.floor(Math.random() * 4);
            this.freezerTemps[zoneIndex] = -8.0;
            this.sendEvent('TEMP_OVERHEAT', { zone_index: zoneIndex, temperature: -8.0, threshold: -10.0 });
        }
        
        // 模拟暴力摇晃 (0.5%)
        if (Math.random() < 0.005) {
            const gForce = parseFloat((Math.random() * 2.5 + 2.5).toFixed(2));
            this.sendEvent('VANDALISM_ALERT', {
                g_force: gForce,
                image_url: `https://oss.example.com/${this.device_no}/alert_${Date.now()}.jpg`,
                video_url: `https://oss.example.com/${this.device_no}/alert_${Date.now()}.mp4`
            });
        }
        
        // 模拟门打开 (0.5%)
        if (Math.random() < 0.005) {
            this.doorClosed = false;
            this.sendEvent('DOOR_OPENED', { door_id: 'MAIN', timestamp: Math.floor(Date.now() / 1000) });
        } else {
            this.doorClosed = true;
        }
        
        const payload = {
            device_no: this.device_no,
            ts: new Date().toISOString(),
            system: {
                voltage: parseFloat((this.voltage + (Math.random() - 0.5)).toFixed(1)),
                current: parseFloat((this.current + (Math.random() - 0.5) * 0.2).toFixed(2)),
                uptime: this.uptime,
                door_closed: this.doorClosed
            },
            environment: {
                freezer_temps: this.freezerTemps,
                ambient_temp: this.ambientTemp,
                vibration_g: this.vibrationG
            },
            connectivity: {
                rssi: this.rssi,
                type: '4G',
                csq: Math.floor((this.rssi + 113) / 2)
            },
            location: {
                lat: parseFloat((this.location.lat + (Math.random() - 0.5) * 0.0001).toFixed(6)),
                lng: parseFloat((this.location.lng + (Math.random() - 0.5) * 0.0001).toFixed(6))
            }
        };
        
        const options = {
            qos: 0,
            properties: {
                contentType: 'application/json',
                userProperties: { priority: 'low' }
            }
        };
        
        this.client.publish(`${this.baseTopic}/telemetry`, JSON.stringify(payload), options);
        console.log(`[TELEMETRY] Sent`);
    }
}

// 启动模拟器
const vm = new FrozenMealVendingMachine('VM-BJ-001');
setInterval(() => vm.sendTelemetry(), 10000);

process.on('SIGINT', () => {
    console.log('Shutting down...');
    vm.client.end();
    process.exit(0);
});

process.on('SIGTERM', () => {
    vm.client.end();
    process.exit(0);
});

console.log(`Simulator started for ${vm.device_no}`);
