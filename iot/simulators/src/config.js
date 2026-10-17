import 'dotenv/config';

// 错误码统一定义
export const ERROR_CODES = {
  E101: '货道库存为空',
  E102: '红外传感器未感应',
  E103: '电机电流过载',
  E201: '微波炉功率异常',
  E202: '微波炉超时',
  E301: '冷冻温区超温',
  E401: 'GPS信号丢失',
  E501: '摄像头离线'
};

// 城市地理坐标基准点 (纬度 lat, 经度 lng)
export const LOCATIONS = {
  SH: { lat: 31.2304, lng: 121.4737 }, // 上海
  SZ: { lat: 22.5431, lng: 114.0579 }, // 深圳
  HN: { lat: 20.0440, lng: 110.3499 }  // 海南海口
};

// 默认 10 台设备模拟集群
export const DEFAULT_DEVICES = [
  'VM-SH-001', 'VM-SH-002', 'VM-SH-003', 'VM-SH-004',
  'VM-SZ-001', 'VM-SZ-002', 'VM-SZ-003',
  'VM-HN-001', 'VM-HN-002', 'VM-HN-003'
].join(',');

// 运行时环境配置
export const config = {
  mqtt: {
    host: process.env.MQTT_HOST || 'localhost',
    port: parseInt(process.env.MQTT_PORT, 10) || 1883,
    username: process.env.MQTT_USERNAME || '',
    password: process.env.MQTT_PASSWORD || '',
    maxReconnects: parseInt(process.env.MQTT_MAX_RECONNECTS, 10) || 10
  },
  simulation: {
    devices: (process.env.DEVICE_NO || DEFAULT_DEVICES)
      .split(',')
      .map(s => s.trim())
      .filter(Boolean),
    reportInterval: parseInt(process.env.REPORT_INTERVAL, 10) || 10000,
    chanceTempOverheat: parseFloat(process.env.EVENT_CHANCE_TEMP_OVERHEAT) || 0,
    chanceVandalism: parseFloat(process.env.EVENT_CHANCE_VANDALISM) || 0,
    chanceDoor: parseFloat(process.env.EVENT_CHANCE_DOOR) || 0
  },
  device: {
    firmware: '5.0.1',
    hardware: 'v3.2',
    channelMealCount: 48,
    channelMealCapacity: 4,
    channelSauceCount: 5,
    channelSauceCapacity: 10
  }
};
