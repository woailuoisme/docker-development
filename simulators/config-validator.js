/**
 * 配置验证工具
 * 用于验证环境变量配置的完整性和正确性
 */

class ConfigValidator {
    constructor() {
        this.errors = [];
        this.warnings = [];
    }

    /**
     * 验证必需的环境变量
     */
    validateRequired(varName, value, description) {
        if (!value || value.trim() === '') {
            this.errors.push(`❌ 缺少必需的环境变量: ${varName} (${description})`);
            return false;
        }
        console.log(`✓ ${varName}: ${this.maskSensitive(varName, value)}`);
        return true;
    }

    /**
     * 验证可选的环境变量
     */
    validateOptional(varName, value, defaultValue, description) {
        if (!value || value.trim() === '') {
            this.warnings.push(`⚠️  ${varName} 未设置，使用默认值: ${defaultValue} (${description})`);
            return defaultValue;
        }
        console.log(`✓ ${varName}: ${this.maskSensitive(varName, value)}`);
        return value;
    }

    /**
     * 验证数字类型
     */
    validateNumber(varName, value, min, max, description) {
        const num = parseInt(value, 10);
        if (isNaN(num)) {
            this.errors.push(`❌ ${varName} 必须是数字: ${value} (${description})`);
            return false;
        }
        if (min !== undefined && num < min) {
            this.errors.push(`❌ ${varName} 必须 >= ${min}, 当前值: ${num}`);
            return false;
        }
        if (max !== undefined && num > max) {
            this.errors.push(`❌ ${varName} 必须 <= ${max}, 当前值: ${num}`);
            return false;
        }
        console.log(`✓ ${varName}: ${num}`);
        return true;
    }

    /**
     * 验证布尔类型
     */
    validateBoolean(varName, value, defaultValue, description) {
        if (!value) {
            this.warnings.push(`⚠️  ${varName} 未设置，使用默认值: ${defaultValue}`);
            return defaultValue;
        }
        const boolValue = value.toLowerCase() === 'true';
        console.log(`✓ ${varName}: ${boolValue}`);
        return boolValue;
    }

    /**
     * 掩码敏感信息
     */
    maskSensitive(varName, value) {
        const sensitiveKeys = ['PASSWORD', 'SECRET', 'TOKEN', 'KEY'];
        if (sensitiveKeys.some(key => varName.includes(key))) {
            return '***';
        }
        return value;
    }

    /**
     * 显示验证结果
     */
    showResults() {
        console.log('\n==========================================');
        
        if (this.warnings.length > 0) {
            console.log('警告:');
            this.warnings.forEach(warning => console.log(warning));
            console.log('');
        }

        if (this.errors.length > 0) {
            console.log('错误:');
            this.errors.forEach(error => console.log(error));
            console.log('==========================================');
            console.log(`❌ 配置验证失败，发现 ${this.errors.length} 个错误`);
            console.log('==========================================\n');
            return false;
        }

        console.log('✓ 配置验证通过');
        console.log('==========================================\n');
        return true;
    }
}

/**
 * 验证设备模拟器配置
 */
function validateSimulatorConfig() {
    console.log('\n==========================================');
    console.log('设备模拟器配置验证');
    console.log('==========================================\n');

    const validator = new ConfigValidator();

    // MQTT 配置
    console.log('MQTT 配置:');
    // 优先使用 MQTT_HOST_EXTERNAL（用于本地开发），否则使用 MQTT_HOST
    const mqttHost = validator.validateOptional(
        'MQTT_HOST_EXTERNAL',
        process.env.MQTT_HOST_EXTERNAL || process.env.MQTT_HOST,
        'localhost',
        'MQTT Broker 主机地址'
    );
    
    const mqttPort = process.env.MQTT_PORT || '1883';
    validator.validateNumber(
        'MQTT_PORT',
        mqttPort,
        1,
        65535,
        'MQTT Broker 端口'
    );

    // 模拟器配置
    console.log('\n模拟器配置:');
    const publishInterval = process.env.SIMULATOR_PUBLISH_INTERVAL || '10000';
    validator.validateNumber(
        'SIMULATOR_PUBLISH_INTERVAL',
        publishInterval,
        1000,
        undefined,
        '数据发布间隔（毫秒）'
    );

    const maxRetries = process.env.SIMULATOR_MAX_RETRIES || '5';
    validator.validateNumber(
        'SIMULATOR_MAX_RETRIES',
        maxRetries,
        1,
        10,
        '最大重试次数'
    );

    const initialDelay = process.env.SIMULATOR_INITIAL_DELAY || '1000';
    validator.validateNumber(
        'SIMULATOR_INITIAL_DELAY',
        initialDelay,
        100,
        undefined,
        '初始重连延迟（毫秒）'
    );

    const maxDelay = process.env.SIMULATOR_MAX_DELAY || '30000';
    validator.validateNumber(
        'SIMULATOR_MAX_DELAY',
        maxDelay,
        1000,
        undefined,
        '最大重连延迟（毫秒）'
    );

    // 显示结果
    const isValid = validator.showResults();
    
    if (!isValid) {
        process.exit(1);
    }

    return {
        mqtt: {
            host: mqttHost,
            port: parseInt(mqttPort, 10)
        },
        simulator: {
            publishInterval: parseInt(publishInterval, 10),
            maxRetries: parseInt(maxRetries, 10),
            initialDelay: parseInt(initialDelay, 10),
            maxDelay: parseInt(maxDelay, 10)
        }
    };
}

module.exports = {
    ConfigValidator,
    validateSimulatorConfig
};
