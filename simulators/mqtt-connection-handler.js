/**
 * MQTT 连接处理器
 * 实现带指数退避的自动重连机制
 */

const mqtt = require('mqtt');
const EventEmitter = require('events');

class MQTTConnectionHandler extends EventEmitter {
    constructor(options = {}) {
        super();
        
        // 连接配置
        this.brokerUrl = options.brokerUrl || `mqtt://${process.env.MQTT_HOST || 'localhost'}:${process.env.MQTT_PORT || 1883}`;
        this.clientId = options.clientId || `mqtt_client_${Date.now()}`;
        
        // 重试配置
        this.maxRetries = parseInt(process.env.SIMULATOR_MAX_RETRIES || '5', 10);
        this.initialDelay = parseInt(process.env.SIMULATOR_INITIAL_DELAY || '1000', 10);
        this.maxDelay = parseInt(process.env.SIMULATOR_MAX_DELAY || '30000', 10);
        this.backoffMultiplier = 2;
        
        // 状态跟踪
        this.currentRetry = 0;
        this.isConnecting = false;
        this.isConnected = false;
        this.client = null;
        this.reconnectTimer = null;
        
        console.log('MQTT 连接处理器初始化:');
        console.log(`  Broker: ${this.brokerUrl}`);
        console.log(`  Client ID: ${this.clientId}`);
        console.log(`  最大重试: ${this.maxRetries}`);
        console.log(`  初始延迟: ${this.initialDelay}ms`);
        console.log(`  最大延迟: ${this.maxDelay}ms`);
    }

    /**
     * 计算下一次重试的延迟时间（指数退避）
     */
    calculateDelay(retryCount) {
        return Math.min(
            this.initialDelay * Math.pow(this.backoffMultiplier, retryCount - 1),
            this.maxDelay
        );
    }

    /**
     * 连接到 MQTT Broker
     */
    async connect() {
        if (this.isConnecting) {
            console.log('⚠️  连接正在进行中，跳过重复连接请求');
            return;
        }

        if (this.isConnected) {
            console.log('✓ 已经连接到 MQTT Broker');
            return this.client;
        }

        this.isConnecting = true;
        this.currentRetry = 0;

        return this._attemptConnection();
    }

    /**
     * 尝试连接（内部方法）
     */
    async _attemptConnection() {
        return new Promise((resolve, reject) => {
            console.log(`\n尝试连接到 MQTT Broker (尝试 ${this.currentRetry + 1}/${this.maxRetries})...`);

            try {
                // MQTT 连接选项
                const connectOptions = {
                    clientId: this.clientId,
                    clean: true,
                    connectTimeout: 10000,
                    reconnectPeriod: 0, // 禁用自动重连，我们手动控制
                };

                // 如果设置了认证信息
                if (process.env.MQTT_USERNAME && process.env.MQTT_PASSWORD) {
                    connectOptions.username = process.env.MQTT_USERNAME;
                    connectOptions.password = process.env.MQTT_PASSWORD;
                }

                this.client = mqtt.connect(this.brokerUrl, connectOptions);

                // 连接成功
                this.client.on('connect', () => {
                    console.log('✓ 成功连接到 MQTT Broker');
                    this.isConnected = true;
                    this.isConnecting = false;
                    this.currentRetry = 0;
                    this.emit('connected', this.client);
                    resolve(this.client);
                });

                // 连接错误
                this.client.on('error', (error) => {
                    console.error(`❌ MQTT 连接错误: ${error.message}`);
                    this.emit('error', error);
                    
                    if (!this.isConnected) {
                        this._handleConnectionFailure(reject);
                    }
                });

                // 连接关闭
                this.client.on('close', () => {
                    if (this.isConnected) {
                        console.log('⚠️  MQTT 连接已关闭');
                        this.isConnected = false;
                        this.emit('disconnected');
                        
                        // 尝试重连
                        this._scheduleReconnect();
                    }
                });

                // 离线事件
                this.client.on('offline', () => {
                    console.log('⚠️  MQTT 客户端离线');
                    this.isConnected = false;
                    this.emit('offline');
                });

            } catch (error) {
                console.error(`❌ 创建 MQTT 客户端失败: ${error.message}`);
                this._handleConnectionFailure(reject);
            }
        });
    }

    /**
     * 处理连接失败
     */
    _handleConnectionFailure(reject) {
        this.currentRetry++;

        if (this.currentRetry >= this.maxRetries) {
            this.isConnecting = false;
            const error = new Error(`达到最大重试次数 (${this.maxRetries})，连接失败`);
            console.error(`❌ ${error.message}`);
            this.emit('maxRetriesReached', error);
            reject(error);
            return;
        }

        const delay = this.calculateDelay(this.currentRetry);
        console.log(`⏳ ${delay}ms 后重试 (${this.currentRetry}/${this.maxRetries})...`);

        this.reconnectTimer = setTimeout(() => {
            this._attemptConnection().catch(reject);
        }, delay);
    }

    /**
     * 安排重连（用于连接断开后）
     */
    _scheduleReconnect() {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
        }

        this.currentRetry = 0;
        const delay = this.initialDelay;
        
        console.log(`⏳ ${delay}ms 后尝试重连...`);
        
        this.reconnectTimer = setTimeout(() => {
            this.isConnecting = false;
            this.connect().catch(error => {
                console.error(`重连失败: ${error.message}`);
            });
        }, delay);
    }

    /**
     * 发布消息
     */
    publish(topic, message, options = {}) {
        return new Promise((resolve, reject) => {
            if (!this.isConnected || !this.client) {
                reject(new Error('未连接到 MQTT Broker'));
                return;
            }

            const messageStr = typeof message === 'string' ? message : JSON.stringify(message);
            
            this.client.publish(topic, messageStr, options, (error) => {
                if (error) {
                    console.error(`发布消息失败: ${error.message}`);
                    reject(error);
                } else {
                    resolve();
                }
            });
        });
    }

    /**
     * 订阅主题
     */
    subscribe(topic, options = {}) {
        return new Promise((resolve, reject) => {
            if (!this.isConnected || !this.client) {
                reject(new Error('未连接到 MQTT Broker'));
                return;
            }

            this.client.subscribe(topic, options, (error, granted) => {
                if (error) {
                    console.error(`订阅主题失败: ${error.message}`);
                    reject(error);
                } else {
                    console.log(`✓ 成功订阅主题: ${topic}`);
                    resolve(granted);
                }
            });
        });
    }

    /**
     * 断开连接
     */
    async disconnect() {
        console.log('正在断开 MQTT 连接...');
        
        // 清除重连定时器
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }

        if (this.client) {
            return new Promise((resolve) => {
                this.client.end(false, {}, () => {
                    console.log('✓ MQTT 连接已断开');
                    this.isConnected = false;
                    this.isConnecting = false;
                    this.client = null;
                    this.emit('closed');
                    resolve();
                });
            });
        }
    }

    /**
     * 获取连接状态
     */
    getStatus() {
        return {
            isConnected: this.isConnected,
            isConnecting: this.isConnecting,
            currentRetry: this.currentRetry,
            maxRetries: this.maxRetries,
            brokerUrl: this.brokerUrl
        };
    }
}

module.exports = MQTTConnectionHandler;
