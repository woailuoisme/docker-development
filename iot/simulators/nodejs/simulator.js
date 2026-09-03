const mqtt = require('mqtt');
require('dotenv').config();
const chalk = require('chalk');

// 错误码统一定义
const ERROR_CODES = {
    "E101": "货道库存为空",
    "E102": "红外传感器未感应",
    "E103": "电机电流过载",
    "E201": "微波炉功率异常",
    "E202": "微波炉超时",
    "E301": "冷冻温区超温",
    "E401": "GPS信号丢失",
    "E501": "摄像头离线"
};

/**
 * 冷链便当自动售货机 MQTT 5.0 完整模拟器 (Node.js)
 * 严格遵循 mqtt_api_doc.md 接口规范
 */
class FrozenMealVendingMachine {
    // 统一日志工具 (使用 chalk)
    log(level, tag, message) {
        // 获取 YYYY-MM-DD HH:mm:ss 格式
        const now = new Date();
        const dateStr = now.toLocaleString('zh-CN', { hour12: false }).replace(/\//g, '-');
        const timestamp = chalk.gray(`[${dateStr}]`);
        let tagged;
        
        switch (level) {
            case 'info': tagged = chalk.green.bold(tag); break;
            case 'warn': tagged = chalk.yellow.bold(tag); break;
            case 'error': tagged = chalk.red.bold(tag); break;
            case 'cmd': tagged = chalk.cyan.bold(tag); break;
            case 'event': tagged = chalk.magenta.bold(tag); break;
            case 'init': tagged = chalk.bgCyan.black.bold(` ${tag} `); break;
            default: tagged = chalk.white(tag);
        }

        console.log(`${timestamp} ${tagged} ${message}`);
    }

    constructor(deviceNo) {
        this.device_no = deviceNo;
        this.host = process.env.MQTT_HOST || 'localhost';
        this.port = process.env.MQTT_PORT || 1883;
        this.reconnectCount = 0;
        this.maxReconnects = parseInt(process.env.MQTT_MAX_RECONNECTS, 10) || 10;
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
        
        // 根据设备ID分配地理位置 (海南、深圳、上海)
        // 默认坐标基准点
        const LOCATIONS = {
            "SH": { lat: 31.2304, lng: 121.4737 }, // 上海
            "SZ": { lat: 22.5431, lng: 114.0579 }, // 深圳
            "HN": { lat: 20.0440, lng: 110.3499 }  // 海南海口
        };

        let baseLoc = LOCATIONS["SH"]; // 默认上海
        if (this.device_no.includes("-SZ-")) baseLoc = LOCATIONS["SZ"];
        else if (this.device_no.includes("-HN-")) baseLoc = LOCATIONS["HN"];
        else if (this.device_no.includes("-SH-")) baseLoc = LOCATIONS["SH"];

        // 增加 0.005-0.01 的随机偏移 (约 500m-1km)，避免点位重合
        this.location = { 
            lat: baseLoc.lat + (Math.random() - 0.5) * 0.02, 
            lng: baseLoc.lng + (Math.random() - 0.5) * 0.02 
        };
        
        // 配置随机事件概率
        this.chanceTempOverheat = parseFloat(process.env.EVENT_CHANCE_TEMP_OVERHEAT) || 0;
        this.chanceVandalism = parseFloat(process.env.EVENT_CHANCE_VANDALISM) || 0;
        this.chanceDoor = parseFloat(process.env.EVENT_CHANCE_DOOR) || 0;
        
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
        this.log('init', '[INIT]', `Attempting to connect to mqtt://${this.host}:${this.port}...`);

        this.client.on('connect', (connack) => {
            this.reconnectCount = 0; // 重连成功后重置计数器
            this.log('info', '[CONNECT]', `${this.device_no} connected successfully (Session: ${connack.sessionPresent}) [Loc: ${this.location.lat.toFixed(2)},${this.location.lng.toFixed(2)}]`);
            
            // 订阅指令主题 (QoS 2)
            this.client.subscribe(`${this.baseTopic}/commands`, { qos: 2 }, (err) => {
                if (err) this.log('error', '[SUBSCRIBE]', `Failed to subscribe: ${err.message}`);
                else this.log('info', '[SUBSCRIBE]', `Subscribed to ${this.baseTopic}/commands`);
            });
            
            // 发布上线状态
            this.publishStatus('online');
        });

        this.client.on('reconnect', () => {
            this.reconnectCount++;
            if (this.reconnectCount > this.maxReconnects) {
                this.log('error', '[FATAL]', `Max reconnection attempts (${this.maxReconnects}) reached. Stopping simulator.`);
                this.client.end(true); // 强制关闭
                process.exit(1);
            }
            this.log('warn', '[RECONNECT]', `Reconnecting to broker (Attempt: ${this.reconnectCount}/${this.maxReconnects})...`);
        });

        this.client.on('offline', () => {
            this.log('warn', '[OFFLINE]', `Client went offline`);
        });

        this.client.on('error', (err) => {
            this.log('error', '[ERROR]', `MQTT Client Error: ${err.message}`);
            if (err.code === 'ENOTFOUND') {
                this.log('error', '[FATAL]', `Host ${this.host} not found. Check your MQTT_HOST config.`);
            } else if (err.code === 'ECONNREFUSED') {
                this.log('error', '[FATAL]', `Connection refused at ${this.host}:${this.port}. Is the broker running?`);
            }
        });

        this.client.on('message', (topic, message) => {
            this.handleCommand(message);
        });
    }

    handleCommand(message) {
        try {
            const payload = JSON.parse(message.toString());
            const { cmd_id, action, params = {} } = payload;
            
            this.log('cmd', '[CMD]', `Received: ${action} (cmd_id: ${cmd_id})`);
            
            // 幂等性检查
            if (this.cmdCache.includes(cmd_id)) {
                this.log('warn', '[CMD]', `Duplicate cmd_id: ${cmd_id}, skipping`);
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
            this.sendAck(cmdId, 'failed', null, { code: 'E101', message: ERROR_CODES["E101"] });
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
            this.sendAck(cmdId, 'failed', null, { code: 'E103', message: ERROR_CODES["E103"] });
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
            this.sendAck(cmdId, 'failed', null, { code: 'E201', message: ERROR_CODES["E201"] });
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
        this.log('cmd', '[VIDEO]', `Starting stream for ${camera_id} -> ${stream_url} (${duration}s)`);
        this.sendAck(cmdId, 'success', { camera_id, streaming: true });
    }

    handleStopVideo(cmdId, params) {
        const { camera_id = 'CAM_TOP' } = params;
        this.log('cmd', '[VIDEO]', `Stopping stream for ${camera_id}`);
        this.sendAck(cmdId, 'success', { camera_id, streaming: false });
    }

    handleReboot(cmdId, params) {
        const { delay = 0, reason = 'remote_command' } = params;
        this.log('warn', '[REBOOT]', `System will reboot in ${delay}s, reason: ${reason}`);
        this.sendAck(cmdId, 'success', { scheduled_at: Math.floor(Date.now() / 1000) + delay });
    }

    handleLockChannel(cmdId, params) {
        const { channel_id } = params;
        this.lockedChannels.add(channel_id);
        this.log('cmd', '[CHANNEL]', `Locked: ${channel_id}`);
        this.sendAck(cmdId, 'success', { channel_id, locked: true });
    }

    handleUnlockChannel(cmdId, params) {
        const { channel_id } = params;
        this.lockedChannels.delete(channel_id);
        this.log('cmd', '[CHANNEL]', `Unlocked: ${channel_id}`);
        this.sendAck(cmdId, 'success', { channel_id, locked: false });
    }

    handleSetConfig(cmdId, params) {
        this.log('cmd', '[CONFIG]', `Updated: ${JSON.stringify(params)}`);
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
        this.log('event', '[EVENT]', `${eventType}`);
    }

    sendAck(cmdId, status, result = null, error = null) {
        const payload = { cmd_id: cmdId, status, result, error };
        this.client.publish(`${this.baseTopic}/commands/ack`, JSON.stringify(payload), { qos: 1 });
        this.log('cmd', '[ACK]', `${cmdId} -> ${status}`);
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
        
        // 模拟超温事件
        if (this.chanceTempOverheat > 0 && Math.random() < this.chanceTempOverheat) {
            const zoneIndex = Math.floor(Math.random() * 4);
            this.freezerTemps[zoneIndex] = -8.0;
            this.sendEvent('TEMP_OVERHEAT', { 
                zone_index: zoneIndex, 
                temperature: -8.0, 
                threshold: -10.0,
                error_code: 'E301'
            });
        }
        
        // 模拟暴力摇晃
        if (this.chanceVandalism > 0 && Math.random() < this.chanceVandalism) {
            const gForce = parseFloat((Math.random() * 2.5 + 2.5).toFixed(2));
            this.sendEvent('VANDALISM_ALERT', {
                g_force: gForce,
                image_url: `https://oss.example.com/${this.device_no}/alert_${Date.now()}.jpg`,
                video_url: `https://oss.example.com/${this.device_no}/alert_${Date.now()}.mp4`
            });
        }
        
        // 模拟门打开
        if (this.chanceDoor > 0 && Math.random() < this.chanceDoor) {
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
        
        const avgTemp = (payload.environment.freezer_temps.reduce((a, b) => a + b, 0) / 4).toFixed(1);
        const status = payload.system.door_closed ? 'Closed' : chalk.red('OPEN');
        this.log('info', '[TELEMETRY]', `Sent. AvgTemp: ${avgTemp}°C | RSSI: ${payload.connectivity.rssi}dBm | Door: ${status}`);
    }
}

// 启动模拟器
// 定义 10 台默认设备
const DEFAULT_DEVICES = [
    'VM-SH-001', 'VM-SH-002', 'VM-SH-003', 'VM-SH-004', // 上海 4 台
    'VM-SZ-001', 'VM-SZ-002', 'VM-SZ-003',              // 深圳 3 台
    'VM-HN-001', 'VM-HN-002', 'VM-HN-003'               // 海南 3 台
].join(',');

const deviceList = (process.env.DEVICE_NO || DEFAULT_DEVICES).split(',').map(s => s.trim());
const reportInterval = parseInt(process.env.REPORT_INTERVAL, 10) || 10000;

deviceList.forEach((id, index) => {
    const vm = new FrozenMealVendingMachine(id);
    
    // 给不同设备增加一个小随机偏移，防止上报时间完全重叠挤占带宽
    const jitter = Math.floor(Math.random() * 2000);
    setTimeout(() => {
        setInterval(() => vm.sendTelemetry(), reportInterval);
    }, index * 500 + jitter);

    // 进程退出逻辑只注册一次
    if (index === 0) {
        process.on('SIGINT', () => {
            vm.log('warn', '[EXIT]', 'Shutting down all simulators...');
            process.exit(0);
        });
    }
});
