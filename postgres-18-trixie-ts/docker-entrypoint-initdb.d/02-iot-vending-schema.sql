-- =============================================================================
-- IoT 售货机业务 Schema 初始化
-- 包含：遥测、事件、设备状态（基于 TimescaleDB 超表）
-- =============================================================================

-- 确保扩展已启用
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- 1. 遥测数据表 (vm_telemetry)
CREATE TABLE IF NOT EXISTS vm_telemetry (
    time            TIMESTAMPTZ NOT NULL,
    device_no       TEXT NOT NULL,
    voltage         DOUBLE PRECISION,
    current         DOUBLE PRECISION,
    uptime          INTEGER,
    door_closed     BOOLEAN,
    freezer_temp_0  DOUBLE PRECISION,
    freezer_temp_1  DOUBLE PRECISION,
    freezer_temp_2  DOUBLE PRECISION,
    freezer_temp_3  DOUBLE PRECISION,
    ambient_temp    DOUBLE PRECISION,
    vibration_g     DOUBLE PRECISION,
    rssi            INTEGER,
    lat             DOUBLE PRECISION,
    lng             DOUBLE PRECISION
);

-- 添加注释
COMMENT ON TABLE vm_telemetry IS '售货机遥测历史数据集';
COMMENT ON COLUMN vm_telemetry.time IS '数据上报/采样时间';
COMMENT ON COLUMN vm_telemetry.device_no IS '设备唯一编号 (格式: VM-地区-编号)';
COMMENT ON COLUMN vm_telemetry.voltage IS '当前输入电压 (V)';
COMMENT ON COLUMN vm_telemetry.current IS '系统总工作电流 (A)';
COMMENT ON COLUMN vm_telemetry.uptime IS '自上次启动以来的持续时长 (秒)';
COMMENT ON COLUMN vm_telemetry.door_closed IS '机门状态: true=关闭, false=开启';
COMMENT ON COLUMN vm_telemetry.freezer_temp_0 IS '冷冻温区0采样温度 (℃)';
COMMENT ON COLUMN vm_telemetry.freezer_temp_1 IS '冷冻温区1采样温度 (℃)';
COMMENT ON COLUMN vm_telemetry.freezer_temp_2 IS '冷冻温区2采样温度 (℃)';
COMMENT ON COLUMN vm_telemetry.freezer_temp_3 IS '冷冻温区3采样温度 (℃)';
COMMENT ON COLUMN vm_telemetry.ambient_temp IS '外部环境气温 (℃)';
COMMENT ON COLUMN vm_telemetry.vibration_g IS '三轴加速度计感应到的瞬间G值';
COMMENT ON COLUMN vm_telemetry.rssi IS '移动网络/WiFi信号强度 (dBm)';
COMMENT ON COLUMN vm_telemetry.lat IS '地理坐标-纬度';
COMMENT ON COLUMN vm_telemetry.lng IS '地理坐标-经度';

-- 转换为超表 (按时间自动分区)
SELECT create_hypertable('vm_telemetry', 'time', if_not_exists => TRUE);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_telemetry_device ON vm_telemetry (device_no, time DESC);

-- 2. 事件数据表 (vm_events)
CREATE TABLE IF NOT EXISTS vm_events (
    time            TIMESTAMPTZ NOT NULL,
    device_no       TEXT NOT NULL,
    event_type      TEXT NOT NULL,
    order_id        TEXT,
    channel_id      TEXT,
    oven_id         TEXT,
    error_code      TEXT,
    image_url       TEXT,
    video_url       TEXT,
    raw_data        JSONB
);

-- 添加注释
COMMENT ON TABLE vm_events IS '售货机业务与异常告警事件记录表';
COMMENT ON COLUMN vm_events.time IS '事件触发时刻';
COMMENT ON COLUMN vm_events.device_no IS '设备唯一编号';
COMMENT ON COLUMN vm_events.event_type IS '事件类型 (DISPENSE_SUCCESS/CHANNEL_JAM等)';
COMMENT ON COLUMN vm_events.order_id IS '关联订单ID (如果有)';
COMMENT ON COLUMN vm_events.channel_id IS '出货或发生异常的货道ID';
COMMENT ON COLUMN vm_events.oven_id IS '关联微波炉ID (OVEN_A/OVEN_B)';
COMMENT ON COLUMN vm_events.error_code IS '故障码，详见附录定义';
COMMENT ON COLUMN vm_events.image_url IS '云端生成的抓拍图片URL';
COMMENT ON COLUMN vm_events.video_url IS '异常现场抓拍短视频URL';
COMMENT ON COLUMN vm_events.raw_data IS '原始事件Payload副本 (JSONB格式)';

SELECT create_hypertable('vm_events', 'time', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_events_device ON vm_events (device_no, time DESC);
CREATE INDEX IF NOT EXISTS idx_events_type ON vm_events (event_type, time DESC);

-- 3. 状态数据表 (vm_status)
CREATE TABLE IF NOT EXISTS vm_status (
    time            TIMESTAMPTZ NOT NULL,
    device_no       TEXT NOT NULL,
    status          TEXT NOT NULL,
    firmware        TEXT,
    hardware        TEXT
);

-- 添加注释
COMMENT ON TABLE vm_status IS '设备在线与硬件版本追踪表';
COMMENT ON COLUMN vm_status.time IS '在线状态变更时间';
COMMENT ON COLUMN vm_status.device_no IS '设备唯一编号';
COMMENT ON COLUMN vm_status.status IS '当前状态: online=在线, offline=离线';
COMMENT ON COLUMN vm_status.firmware IS '上报时的固件版本号';
COMMENT ON COLUMN vm_status.hardware IS '机器底层硬件版本';

SELECT create_hypertable('vm_status', 'time', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_status_device ON vm_status (device_no, time DESC);

-- 4. 数据保留策略 (可选启用的策略)
-- SELECT add_retention_policy('vm_telemetry', INTERVAL '30 days', if_not_exists => TRUE);
-- SELECT add_retention_policy('vm_events', INTERVAL '90 days', if_not_exists => TRUE);
