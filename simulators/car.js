/**
 * 车联网数据模拟器 - MQTTX 场景文件
 * 
 * 此脚本模拟真实车辆的各种传感器数据，包括位置、速度、车辆状态、环境参数等
 * 适用于车联网、智能交通系统、车队管理等应用场景
 * 
 * @version 2.0
 * @author Local IoT Project
 */
function generator(faker) {
    // 工具函数：从数组中随机选择元素
    const randomElement = (arr) => arr[Math.floor(Math.random() * arr.length)];
    
    // 工具函数：生成车辆唯一标识符
    const generateVehicleId = () => {
        const prefixes = ['京A', '沪B', '粤C', '苏D', '浙E', '鲁F', '川G'];
        const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        const numbers = '0123456789';
        
        const prefix = randomElement(prefixes);
        const letter = randomElement(letters.split(''));
        const num1 = randomElement(numbers.split(''));
        const num2 = randomElement(numbers.split(''));
        const num3 = randomElement(numbers.split(''));
        const num4 = randomElement(numbers.split(''));
        const num5 = randomElement(numbers.split(''));
        
        return `${prefix}${letter}${num1}${num2}${num3}${num4}${num5}`;
    };

    // 模拟车辆类型和品牌
    const vehicleTypes = [
        { type: '轿车', brand: 'Toyota', model: 'Camry' },
        { type: 'SUV', brand: 'Honda', model: 'CR-V' },
        { type: 'MPV', brand: 'Buick', model: 'GL8' },
        { type: '跑车', brand: 'Porsche', model: '911' },
        { type: '电动车', brand: 'Tesla', model: 'Model 3' },
        { type: '货车', brand: 'Ford', model: 'Transit' }
    ];

    const vehicle = randomElement(vehicleTypes);
    
    // 生成车辆数据
    const vehicleData = {
        // 车辆基本信息
        vehicleId: generateVehicleId(),
        timestamp: new Date().toISOString(),
        
        // 车辆属性
        vehicleInfo: {
            type: vehicle.type,
            brand: vehicle.brand,
            model: vehicle.model,
            year: faker.number.int({ min: 2018, max: 2024 }),
            color: randomElement(['白色', '黑色', '银色', '红色', '蓝色', '灰色']),
            vin: faker.vehicle.vin(),
            mileage: faker.number.int({ min: 5000, max: 150000 })
        },
        
        // 位置和导航数据
        location: {
            latitude: parseFloat(faker.location.latitude({ min: 30, max: 40, precision: 6 })),  // 中国纬度范围
            longitude: parseFloat(faker.location.longitude({ min: 110, max: 122, precision: 6 })), // 中国经度范围
            altitude: faker.number.int({ min: 0, max: 2000 }),
            speed: faker.number.int({ min: 0, max: 120 }), // km/h
            heading: faker.number.int({ min: 0, max: 359 }), // 方向角度
            accuracy: faker.number.int({ min: 1, max: 10 }) // GPS精度(米)
        },
        
        // 动力系统状态
        powertrain: {
            engineStatus: randomElement(['Running', 'Off', 'Idle']),
            fuelLevel: faker.number.float({ min: 5, max: 100, fractionDigits: 2 }), // 燃油百分比
            batteryLevel: faker.number.float({ min: 20, max: 100, fractionDigits: 2 }), // 电池电量百分比
            engineTemperature: faker.number.float({ min: 70, max: 110, fractionDigits: 2 }), // 发动机温度(℃)
            oilPressure: faker.number.float({ min: 20, max: 60, fractionDigits: 2 }), // 油压(psi)
            rpm: faker.number.int({ min: 600, max: 4000 }) // 发动机转速
        },
        
        // 轮胎状态
        tires: {
            frontLeft: {
                pressure: faker.number.float({ min: 30, max: 40, fractionDigits: 2 }),
                temperature: faker.number.float({ min: 15, max: 45, fractionDigits: 2 }),
                wear: faker.number.float({ min: 2, max: 8, fractionDigits: 2 })
            },
            frontRight: {
                pressure: faker.number.float({ min: 30, max: 40, fractionDigits: 2 }),
                temperature: faker.number.float({ min: 15, max: 45, fractionDigits: 2 }),
                wear: faker.number.float({ min: 2, max: 8, fractionDigits: 2 })
            },
            rearLeft: {
                pressure: faker.number.float({ min: 30, max: 40, fractionDigits: 2 }),
                temperature: faker.number.float({ min: 15, max: 45, fractionDigits: 2 }),
                wear: faker.number.float({ min: 2, max: 8, fractionDigits: 2 })
            },
            rearRight: {
                pressure: faker.number.float({ min: 30, max: 40, fractionDigits: 2 }),
                temperature: faker.number.float({ min: 15, max: 45, fractionDigits: 2 }),
                wear: faker.number.float({ min: 2, max: 8, fractionDigits: 2 })
            }
        },
        
        // 车门和车窗状态
        doors: {
            driver: randomElement(['Open', 'Closed', 'Ajar']),
            passenger: randomElement(['Open', 'Closed', 'Ajar']),
            rearLeft: randomElement(['Open', 'Closed', 'Ajar']),
            rearRight: randomElement(['Open', 'Closed', 'Ajar']),
            trunk: randomElement(['Open', 'Closed', 'Ajar']),
            hood: randomElement(['Open', 'Closed'])
        },
        
        windows: {
            driver: faker.number.float({ min: 0, max: 100, fractionDigits: 2 }), // 开度百分比
            passenger: faker.number.float({ min: 0, max: 100, fractionDigits: 2 }),
            rearLeft: faker.number.float({ min: 0, max: 100, fractionDigits: 2 }),
            rearRight: faker.number.float({ min: 0, max: 100, fractionDigits: 2 })
        },
        
        // 环境参数
        environment: {
            internalTemperature: faker.number.float({ min: 15, max: 35, fractionDigits: 2 }),
            externalTemperature: faker.number.float({ min: -10, max: 40, fractionDigits: 2 }),
            humidity: faker.number.float({ min: 20, max: 90, fractionDigits: 2 }),
            airQuality: faker.number.int({ min: 0, max: 500 }), // AQI指数
            lightLevel: faker.number.int({ min: 0, max: 1000 }) // 光照强度(lux)
        },
        
        // 安全系统
        safety: {
            seatbeltDriver: faker.datatype.boolean(),
            seatbeltPassenger: faker.datatype.boolean(),
            airbagStatus: 'Normal',
            absStatus: 'Active',
            tractionControl: 'Active',
            parkingBrake: faker.datatype.boolean()
        },
        
        // 诊断信息
        diagnostics: {
            checkEngineLight: faker.datatype.boolean({ probability: 0.05 }), // 5%概率亮灯
            maintenanceRequired: faker.datatype.boolean({ probability: 0.1 }), // 10%概率需要保养
            lastServiceMileage: faker.number.int({ min: 0, max: 10000 }),
            diagnosticCodes: faker.datatype.boolean({ probability: 0.02 }) ? ['P0300'] : [] // 2%概率有故障码
        },
        
        // 驾驶行为
        drivingBehavior: {
            acceleration: faker.number.float({ min: -5, max: 5, fractionDigits: 2 }), // 加速度 m/s²
            braking: faker.datatype.boolean({ probability: 0.1 }), // 10%概率正在刹车
            steeringAngle: faker.number.int({ min: -180, max: 180 }), // 方向盘角度
            gearPosition: randomElement(['P', 'R', 'N', 'D', '1', '2', '3', '4', '5', '6'])
        }
    };

    return {
        message: JSON.stringify(vehicleData),
        topic: `vehicles/${vehicleData.vehicleId}/telemetry` // 动态主题名称
    };
}

// 导出场景模块
module.exports = {
    name: 'vehicleTelemetryScenario',   // 场景名称
    generator,                          // 生成器函数
    description: '车联网车辆遥测数据模拟器 - 生成完整的车辆状态和传感器数据',
    version: '2.0'
};
