import mqtt from 'mqtt';
import { config } from './config.js';
import { log } from './logger.js';

/**
 * 售货机 MQTT 5.0 通讯层适配器
 * 职责：连接生命周期维护、遗嘱消息 (LWT)、Topic 订阅与标准化消息发布。
 */
export class VendingMqttClient {
  /**
   * @param {import('./machine.js').FrozenMealVendingMachine} machine 设备领域状态机
   */
  constructor(machine) {
    this.machine = machine;
    this.deviceNo = machine.deviceNo;
    this.baseTopic = `v1/vm/${this.deviceNo}`;
    this.reconnectCount = 0;
    this.maxReconnects = config.mqtt.maxReconnects;

    this.client = null;
    this.bindMachineEvents();
    this.connect();
  }

  /**
   * 监听 Machine 触发的领域事件，并转化为 MQTT 消息对外发布
   */
  bindMachineEvents() {
    this.machine.on('ack', ({ cmdId, status, result, error }) => {
      this.sendAck(cmdId, status, result, error);
    });

    this.machine.on('event', ({ eventType, data }) => {
      this.sendEvent(eventType, data);
    });
  }

  /**
   * 建立 MQTT 5.0 连接
   */
  connect() {
    const { host, port, username, password } = config.mqtt;

    const options = {
      clientId: `VM_${this.deviceNo}_${Math.random().toString(16).slice(2, 6)}`,
      protocolVersion: 5,
      clean: true,
      will: {
        topic: `${this.baseTopic}/status`,
        payload: JSON.stringify({
          status: 'offline',
          device_no: this.deviceNo,
          reason: 'unexpected',
          ts: Math.floor(Date.now() / 1000)
        }),
        qos: 1,
        retain: true
      }
    };

    if (username) {
      options.username = username;
      options.password = password;
    }

    log('init', '[INIT]', `[${this.deviceNo}] Attempting to connect to mqtt://${host}:${port}...`);
    this.client = mqtt.connect(`mqtt://${host}:${port}`, options);

    this.setupClientHandlers(host, port);
  }

  /**
   * 注册 MQTT 客户端网络事件回调
   */
  setupClientHandlers(host, port) {
    this.client.on('connect', connack => {
      this.reconnectCount = 0;
      const { lat, lng } = this.machine.location;
      log(
        'info',
        '[CONNECT]',
        `${this.deviceNo} connected (Session: ${connack.sessionPresent}) [Loc: ${lat.toFixed(2)},${lng.toFixed(2)}]`
      );

      // 订阅远程控制指令 (QoS 2)
      this.client.subscribe(`${this.baseTopic}/commands`, { qos: 2 }, err => {
        if (err) {
          log('error', '[SUBSCRIBE]', `Failed to subscribe ${this.baseTopic}/commands: ${err.message}`);
        } else {
          log('info', '[SUBSCRIBE]', `Subscribed to ${this.baseTopic}/commands`);
        }
      });

      // 发布上线在线状态
      this.publishStatus('online');
    });

    this.client.on('reconnect', () => {
      this.reconnectCount++;
      if (this.reconnectCount > this.maxReconnects) {
        log('error', '[FATAL]', `[${this.deviceNo}] Max reconnect attempts (${this.maxReconnects}) reached. Stopping.`);
        this.client.end(true);
        process.exit(1);
      }
      log(
        'warn',
        '[RECONNECT]',
        `[${this.deviceNo}] Reconnecting (Attempt ${this.reconnectCount}/${this.maxReconnects})...`
      );
    });

    this.client.on('offline', () => {
      log('warn', '[OFFLINE]', `[${this.deviceNo}] Client went offline`);
    });

    this.client.on('error', err => {
      log('error', '[ERROR]', `[${this.deviceNo}] MQTT Error: ${err.message}`);
      if (err.code === 'ENOTFOUND') {
        log('error', '[FATAL]', `Host ${host} not found. Check MQTT_HOST config.`);
      } else if (err.code === 'ECONNREFUSED') {
        log('error', '[FATAL]', `Connection refused at ${host}:${port}. Is Mosquitto running?`);
      }
    });

    this.client.on('message', (_topic, message) => {
      this.handleIncomingMessage(message);
    });
  }

  /**
   * 处理云端下发消息并转发给 Machine
   * @param {Buffer} message
   */
  handleIncomingMessage(message) {
    try {
      const payload = JSON.parse(message.toString());
      const { cmd_id, action, params = {} } = payload;
      log('cmd', '[CMD]', `[${this.deviceNo}] Received: ${action} (cmd_id: ${cmd_id})`);

      this.machine.executeCommand({ cmd_id, action, params });
    } catch (e) {
      log('error', '[ERROR]', `[${this.deviceNo}] Failed to parse incoming command: ${e.message}`);
    }
  }

  // ==================== 消息发布方法 ====================

  /**
   * 发布遥测数据 (QoS 0)
   * @param {object} payload
   */
  publishTelemetry(payload) {
    if (!this.client?.connected) return;

    const options = {
      qos: 0,
      properties: {
        contentType: 'application/json',
        userProperties: { priority: 'low' }
      }
    };

    this.client.publish(`${this.baseTopic}/telemetry`, JSON.stringify(payload), options);
  }

  /**
   * 发布设备业务事件 (QoS 1)
   * @param {string} eventType
   * @param {object} data
   */
  sendEvent(eventType, data) {
    if (!this.client?.connected) return;

    const payload = {
      event_type: eventType,
      data,
      ts: Math.floor(Date.now() / 1000)
    };

    const isHighPriority = eventType.includes('FAIL') || eventType.includes('JAM');
    const options = {
      qos: 1,
      properties: {
        contentType: 'application/json',
        userProperties: { priority: isHighPriority ? 'high' : 'normal' }
      }
    };

    this.client.publish(`${this.baseTopic}/events`, JSON.stringify(payload), options);
    log('event', '[EVENT]', `[${this.deviceNo}] ${eventType}`);
  }

  /**
   * 发布指令确认应答 ACK (QoS 1)
   * @param {string} cmdId
   * @param {'success'|'failed'|'rejected'} status
   * @param {object|null} result
   * @param {object|null} error
   */
  sendAck(cmdId, status, result = null, error = null) {
    if (!this.client?.connected) return;

    const payload = { cmd_id: cmdId, status, result, error };
    this.client.publish(`${this.baseTopic}/commands/ack`, JSON.stringify(payload), { qos: 1 });
    log('cmd', '[ACK]', `[${this.deviceNo}] ${cmdId} -> ${status}`);
  }

  /**
   * 发布设备在线/离线状态 (QoS 1, retain: true)
   * @param {'online'|'offline'} status
   */
  publishStatus(status) {
    if (!this.client?.connected) return;

    const payload = {
      status,
      device_no: this.deviceNo,
      firmware: config.device.firmware,
      hardware: config.device.hardware,
      ts: Math.floor(Date.now() / 1000)
    };

    this.client.publish(`${this.baseTopic}/status`, JSON.stringify(payload), { qos: 1, retain: true });
  }

  /**
   * 优雅关闭连接
   */
  close() {
    if (this.client) {
      this.publishStatus('offline');
      this.client.end();
    }
  }
}
