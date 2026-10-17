import chalk from 'chalk';
import { config } from './config.js';
import { log } from './logger.js';
import { FrozenMealVendingMachine } from './machine.js';
import { VendingMqttClient } from './mqtt.js';

/**
 * 售货机模拟器集群调度入口
 * 职责：解析设备列表、启动多机实例、打散网络上报 Jitter、统一处理系统优雅停机。
 */
function main() {
  const { devices, reportInterval } = config.simulation;
  log('init', '[BOOT]', `Starting Vending Machine Simulator Cluster (${devices.length} devices)...`);

  const instances = [];
  const timers = [];

  devices.forEach((deviceNo, index) => {
    const machine = new FrozenMealVendingMachine(deviceNo);
    const mqttClient = new VendingMqttClient(machine);

    instances.push({ machine, mqttClient });

    // 为各设备增加 0~2000ms 随机抖动 (Jitter)，避免遥测上报瞬时重叠挤占 Broker 网络带宽
    const jitter = Math.floor(Math.random() * 2000);
    const startupDelay = index * 500 + jitter;

    const initialTimeout = setTimeout(() => {
      const intervalTimer = setInterval(() => {
        const payload = machine.generateTelemetry();
        mqttClient.publishTelemetry(payload);

        const avgTemp = (
          payload.environment.freezer_temps.reduce((sum, t) => sum + t, 0) /
          payload.environment.freezer_temps.length
        ).toFixed(1);
        const doorStatus = payload.system.door_closed ? 'Closed' : chalk.red('OPEN');

        log(
          'info',
          '[TELEMETRY]',
          `[${deviceNo}] Sent. AvgTemp: ${avgTemp}°C | RSSI: ${payload.connectivity.rssi}dBm | Door: ${doorStatus}`
        );
      }, reportInterval);

      timers.push(intervalTimer);
    }, startupDelay);

    timers.push(initialTimeout);
  });

  // 优雅停机信号捕获
  const shutdown = (signal) => {
    log('warn', '[EXIT]', `Received ${signal}. Shutting down all simulators gracefully...`);
    timers.forEach(t => clearTimeout(t));
    instances.forEach(({ mqttClient }) => mqttClient.close());
    setTimeout(() => {
      process.exit(0);
    }, 500);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main();
