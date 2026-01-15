// IoT Device Simulator - Simplified
// 加载环境变量
require('dotenv').config();

const { faker } = require('@faker-js/faker');
const MQTTConnectionHandler = require('./mqtt-connection-handler');
const { validateSimulatorConfig } = require('./config-validator');
const { generateDeviceStatusTopic } = require('./mqtt-topic-generator');

class IoTDeviceSimulator {
    constructor() {
        // 验证配置
        this.config = validateSimulatorConfig();
        
        // 初始化 MQTT 连接处理器
        this.mqttHandler = new MQTTConnectionHandler({
            brokerUrl: `mqtt://${this.config.mqtt.host}:${this.config.mqtt.port}`,
            clientId: `iot_simulator_${Date.now()}`
        });
        
        // 状态跟踪
        this.isPublishing = false;
        this.publishTimer = null;
        
        // 简化的设备配置 - 只保留必要字段
        this.devices = [
            { id: 'VM001', location: '办公楼大堂', type: 'cooling' },
            { id: 'VM002', location: '地铁站B口', type: 'normal' },
            { id: 'VM003', location: '商场3楼', type: 'cooling' },
            { id: 'VM004', location: '学校食堂', type: 'cooling' },
            { id: 'VM005', location: '医院候诊区', type: 'cooling' }
        ];

        // 设置事件监听器
        this.setupEventListeners();
    }

    /**
     * 设置 MQTT 事件监听器
     */
    setupEventListeners() {
        this.mqttHandler.on('connected', () => {
            console.log('\n✓ 已连接到 MQTT Broker，开始模拟数据...\n');
            this.startSimulation();
        });

        this.mqttHandler.on('disconnected', () => {
            console.log('\n⚠️  与 MQTT Broker 断开连接，停止数据发布\n');
            this.stopPublishing();
        });

        this.mqttHandler.on('offline', () => {
            console.log('\n⚠️  MQTT 客户端离线\n');
            this.stopPublishing();
        });

        this.mqttHandler.on('error', (error) => {
            console.error(`\n❌ MQTT 错误: ${error.message}\n`);
        });

        this.mqttHandler.on('maxRetriesReached', (error) => {
            console.error(`\n❌ 无法连接到 MQTT Broker: ${error.message}`);
            console.error('请检查:');
            console.error('  1. MQTT Broker 是否正在运行');
            console.error('  2. 网络连接是否正常');
            console.error('  3. 认证信息是否正确\n');
            process.exit(1);
        });
    }

    /**
     * 启动模拟器
     */
    async start() {
        try {
            await this.mqttHandler.connect();
        } catch (error) {
            console.error(`启动失败: ${error.message}`);
            process.exit(1);
        }
    }

    /**
     * 生成简化的设备状态数据
     */
    generateStatusData(device) {
        // 生成设备状态
        const rand = faker.number.int({ min: 1, max: 100 });
        let status;
        if (rand <= 90) status = 'online';
        else if (rand <= 95) status = 'maintenance';
        else status = 'offline';

        // online 字段应该与 status 一致
        const online = status !== 'offline';

        // 根据设备类型生成温度数据
        const temperature = device.type === 'cooling' ?
            faker.number.float({ min: 2, max: 8, fractionDigits: 1 }) :
            faker.number.float({ min: 15, max: 25, fractionDigits: 1 });

        // 生成网络信号强度
        const network_strength = faker.number.int({ min: -80, max: -40 });

        return {
            device_id: device.id,
            location: device.location,
            status: status,
            timestamp: new Date().toISOString(),
            online: online,
            temperature: temperature,
            network_strength: network_strength
        };
    }

    /**
     * 开始发布数据
     */
    startSimulation() {
        if (this.isPublishing) {
            console.log('⚠️  数据发布已在进行中');
            return;
        }

        this.isPublishing = true;
        console.log(`开始发布数据，间隔: ${this.config.simulator.publishInterval}ms\n`);

        this.publishTimer = setInterval(async () => {
            if (!this.mqttHandler.isConnected) {
                console.log('⚠️  未连接，跳过本次发布');
                return;
            }

            try {
                await this.publishAllData();
            } catch (error) {
                console.error(`发布数据失败: ${error.message}`);
            }
        }, this.config.simulator.publishInterval);
    }

    /**
     * 停止发布数据
     */
    stopPublishing() {
        if (this.publishTimer) {
            clearInterval(this.publishTimer);
            this.publishTimer = null;
        }
        this.isPublishing = false;
        console.log('✓ 已停止数据发布');
    }

    /**
     * 发布所有设备的数据
     */
    async publishAllData() {
        const publishPromises = [];

        for (const device of this.devices) {
            // 生成并发布状态数据
            const statusData = this.generateStatusData(device);
            const topic = generateDeviceStatusTopic(device.id);
            publishPromises.push(
                this.mqttHandler.publish(
                    topic,
                    statusData
                )
            );
        }

        await Promise.all(publishPromises);
        console.log(`✓ 数据已发送 - ${new Date().toLocaleString()}`);
    }

    /**
     * 优雅关闭
     */
    async shutdown() {
        console.log('\n========================================');
        console.log('开始优雅关闭...');
        console.log('========================================\n');

        // 1. 停止发布数据
        this.stopPublishing();

        // 2. 断开 MQTT 连接
        await this.mqttHandler.disconnect();

        console.log('\n========================================');
        console.log('✓ 优雅关闭完成');
        console.log('========================================\n');
    }
}

// 启动模拟器
const simulator = new IoTDeviceSimulator();

// 设置信号处理器
process.on('SIGTERM', async () => {
    console.log('\n收到 SIGTERM 信号');
    await simulator.shutdown();
    process.exit(0);
});

process.on('SIGINT', async () => {
    console.log('\n收到 SIGINT 信号 (Ctrl+C)');
    await simulator.shutdown();
    process.exit(0);
});

// 处理未捕获的异常
process.on('uncaughtException', async (error) => {
    console.error('\n❌ 未捕获的异常:', error);
    await simulator.shutdown();
    process.exit(1);
});

process.on('unhandledRejection', async (reason, promise) => {
    console.error('\n❌ 未处理的 Promise 拒绝:', reason);
    await simulator.shutdown();
    process.exit(1);
});

// 启动
console.log('\n========================================');
console.log('IoT 设备监控模拟器');
console.log('========================================\n');

simulator.start().catch(error => {
    console.error(`启动失败: ${error.message}`);
    process.exit(1);
});