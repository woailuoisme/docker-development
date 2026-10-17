import { EventEmitter } from 'node:events';
import { ERROR_CODES, LOCATIONS, config } from './config.js';

/**
 * 冷链便当自动售货机核心领域模型 (IoT Edge State Machine)
 * 职责：维护机身硬件状态、货道库存、温控与传感器读数，处理设备控制指令并触发领域事件。
 */
export class FrozenMealVendingMachine extends EventEmitter {
  constructor(deviceNo) {
    super();
    this.deviceNo = deviceNo;

    // 货道库存 (48 个便当货道，5 个酱包货道)
    this.mealChannels = {};
    for (let i = 1; i <= config.device.channelMealCount; i++) {
      const channelId = `M-${i.toString().padStart(2, '0')}`;
      this.mealChannels[channelId] = config.device.channelMealCapacity;
    }

    this.sauceChannels = {};
    for (let i = 1; i <= config.device.channelSauceCount; i++) {
      const channelId = `S-${i.toString().padStart(2, '0')}`;
      this.sauceChannels[channelId] = config.device.channelSauceCapacity;
    }

    this.lockedChannels = new Set();

    // 微波加热单元
    this.ovens = {
      OVEN_A: { status: 'idle', power: 0 },
      OVEN_B: { status: 'idle', power: 0 }
    };

    // 传感器状态基准值
    this.freezerTemps = [-18.5, -19.0, -18.2, -18.8];
    this.ambientTemp = 25.0;
    this.voltage = 220.5;
    this.current = 1.2;
    this.uptime = 0;
    this.doorClosed = true;
    this.vibrationG = 0.02;
    this.rssi = -65;

    // 地理位置初始化 (基于设备编号规则分配，附加随机偏移模拟真实网格点位)
    this.location = this.initLocation(deviceNo);

    // 指令幂等缓存 (环形滑动窗口，最多保存 100 条)
    this.cmdCache = [];
  }

  /**
   * 根据设备编号前缀计算地理坐标基准点及随机偏移
   * @param {string} deviceNo
   * @returns {{ lat: number, lng: number }}
   */
  initLocation(deviceNo) {
    let baseLoc = LOCATIONS.SH;
    if (deviceNo.includes('-SZ-')) baseLoc = LOCATIONS.SZ;
    else if (deviceNo.includes('-HN-')) baseLoc = LOCATIONS.HN;
    else if (deviceNo.includes('-SH-')) baseLoc = LOCATIONS.SH;

    return {
      lat: baseLoc.lat + (Math.random() - 0.5) * 0.02,
      lng: baseLoc.lng + (Math.random() - 0.5) * 0.02
    };
  }

  /**
   * 执行下发控制指令
   * @param {{ cmd_id: string, action: string, params: object }} commandPayload
   */
  executeCommand({ cmd_id, action, params = {} }) {
    // 幂等性校验
    if (this.cmdCache.includes(cmd_id)) {
      this.emit('ack', {
        cmdId: cmd_id,
        status: 'success',
        result: { note: 'duplicate, already executed' }
      });
      return;
    }

    this.cmdCache.push(cmd_id);
    if (this.cmdCache.length > 100) this.cmdCache.shift();

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
        this.emit('ack', {
          cmdId: cmd_id,
          status: 'rejected',
          result: null,
          error: { code: 'E000', message: `Unknown action: ${action}` }
        });
    }
  }

  // ==================== 业务动作实现 ====================

  handleDispense(cmdId, params) {
    const startTime = Date.now();
    const {
      order_id = 'ORD_UNKNOWN',
      meal_cid = 'M-01',
      sauce_cid = 'S-01',
      oven_id = 'OVEN_A',
      heat_seconds = 90
    } = params;

    // 检查货道是否锁定
    if (this.lockedChannels.has(meal_cid)) {
      this.emit('ack', {
        cmdId,
        status: 'failed',
        result: null,
        error: { code: 'E103', message: `Channel ${meal_cid} is locked` }
      });
      return;
    }

    // 检查货道库存
    if ((this.mealChannels[meal_cid] || 0) <= 0) {
      this.emit('event', {
        eventType: 'DISPENSE_FAILED',
        data: { order_id, meal_cid, error_code: 'E101' }
      });
      this.emit('ack', {
        cmdId,
        status: 'failed',
        result: null,
        error: { code: 'E101', message: ERROR_CODES.E101 }
      });
      return;
    }

    // 模拟出货机械卡货故障 (3% 概率)
    if (Math.random() < 0.03) {
      this.lockedChannels.add(meal_cid);
      this.emit('event', {
        eventType: 'CHANNEL_JAM',
        data: {
          channel_id: meal_cid,
          motor_current: parseFloat((Math.random() + 4).toFixed(2)),
          error_code: 'E103',
          image_url: `https://oss.example.com/${this.deviceNo}/jam_${Date.now()}.jpg`
        }
      });
      this.emit('ack', {
        cmdId,
        status: 'failed',
        result: null,
        error: { code: 'E103', message: ERROR_CODES.E103 }
      });
      return;
    }

    // 模拟加热模块功率异常 (2% 概率)
    if (Math.random() < 0.02) {
      this.emit('event', {
        eventType: 'HEATING_FAILURE',
        data: {
          oven_id,
          expected_power: 1100,
          actual_power: Math.floor(Math.random() * 50) + 10,
          exhaust_temp: parseFloat((22 + Math.random() * 3).toFixed(1))
        }
      });
      this.emit('ack', {
        cmdId,
        status: 'failed',
        result: null,
        error: { code: 'E201', message: ERROR_CODES.E201 }
      });
      return;
    }

    // 扣减商品与酱料库存
    this.mealChannels[meal_cid]--;
    this.sauceChannels[sauce_cid] = Math.max(0, (this.sauceChannels[sauce_cid] || 0) - 1);

    // 出货成功事件
    this.emit('event', {
      eventType: 'DISPENSE_SUCCESS',
      data: {
        order_id,
        meal_cid,
        sauce_cid,
        oven_id,
        heat_duration: heat_seconds,
        image_url: `https://oss.example.com/${this.deviceNo}/dispense_${Date.now()}.jpg`
      }
    });

    const durationMs = Date.now() - startTime + heat_seconds * 1000;
    this.emit('ack', {
      cmdId,
      status: 'success',
      result: {
        executed_at: Math.floor(Date.now() / 1000),
        duration_ms: durationMs
      }
    });
  }

  handleStartVideo(cmdId, { camera_id = 'CAM_TOP' } = {}) {
    this.emit('ack', {
      cmdId,
      status: 'success',
      result: { camera_id, streaming: true }
    });
  }

  handleStopVideo(cmdId, { camera_id = 'CAM_TOP' } = {}) {
    this.emit('ack', {
      cmdId,
      status: 'success',
      result: { camera_id, streaming: false }
    });
  }

  handleReboot(cmdId, { delay = 0 } = {}) {
    this.emit('ack', {
      cmdId,
      status: 'success',
      result: { scheduled_at: Math.floor(Date.now() / 1000) + delay }
    });
  }

  handleLockChannel(cmdId, { channel_id } = {}) {
    if (channel_id) this.lockedChannels.add(channel_id);
    this.emit('ack', {
      cmdId,
      status: 'success',
      result: { channel_id, locked: true }
    });
  }

  handleUnlockChannel(cmdId, { channel_id } = {}) {
    if (channel_id) this.lockedChannels.delete(channel_id);
    this.emit('ack', {
      cmdId,
      status: 'success',
      result: { channel_id, locked: false }
    });
  }

  handleSetConfig(cmdId, params = {}) {
    this.emit('ack', {
      cmdId,
      status: 'success',
      result: { updated: Object.keys(params) }
    });
  }

  // ==================== 遥测与环境感知 ====================

  /**
   * 刷新传感器状态并生成标准化遥测数据 Payload
   * @returns {object} MQTT 5.0 协议规范遥测 Payload
   */
  generateTelemetry() {
    this.uptime += 10;
    this.rssi = Math.max(-110, Math.min(-40, this.rssi + Math.floor(Math.random() * 5 - 2)));

    // 模拟冷柜温区波动与环境气温
    this.freezerTemps = this.freezerTemps.map(t =>
      parseFloat((t + (Math.random() - 0.5) * 0.2).toFixed(2))
    );
    this.ambientTemp = parseFloat((25 + Math.random() * 2).toFixed(1));
    this.vibrationG = parseFloat((Math.random() * 0.05).toFixed(3));

    // 随机模拟温区超温报警
    if (config.simulation.chanceTempOverheat > 0 && Math.random() < config.simulation.chanceTempOverheat) {
      const zoneIndex = Math.floor(Math.random() * 4);
      this.freezerTemps[zoneIndex] = -8.0;
      this.emit('event', {
        eventType: 'TEMP_OVERHEAT',
        data: {
          zone_index: zoneIndex,
          temperature: -8.0,
          threshold: -10.0,
          error_code: 'E301'
        }
      });
    }

    // 随机模拟暴力撞击与破坏
    if (config.simulation.chanceVandalism > 0 && Math.random() < config.simulation.chanceVandalism) {
      const gForce = parseFloat((Math.random() * 2.5 + 2.5).toFixed(2));
      this.emit('event', {
        eventType: 'VANDALISM_ALERT',
        data: {
          g_force: gForce,
          image_url: `https://oss.example.com/${this.deviceNo}/alert_${Date.now()}.jpg`,
          video_url: `https://oss.example.com/${this.deviceNo}/alert_${Date.now()}.mp4`
        }
      });
    }

    // 随机模拟门异常开启
    if (config.simulation.chanceDoor > 0 && Math.random() < config.simulation.chanceDoor) {
      this.doorClosed = false;
      this.emit('event', {
        eventType: 'DOOR_OPENED',
        data: { door_id: 'MAIN', timestamp: Math.floor(Date.now() / 1000) }
      });
    } else {
      this.doorClosed = true;
    }

    return {
      device_no: this.deviceNo,
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
  }
}
