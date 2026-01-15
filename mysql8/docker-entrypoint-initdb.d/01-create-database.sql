-- ############################################################
-- MySQL 8.4 初始化脚本示例
-- 此脚本仅在 /var/lib/mysql 目录为空(即首次启动容器)时执行
-- ############################################################

-- 1. 创建额外的数据库 (如果需要除了 MYSQL_DATABASE 以外的库)
-- 例如创建一个测试环境数据库
CREATE DATABASE IF NOT EXISTS `test_database` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 2. 额外用户授权 (如果需要特定的权限或额外的管理账户)
-- 注意：MYSQL_USER 变量已经由镜像自动创建。
-- 这里我们确保该用户拥有主数据库的所有权限（通常默认已拥有，此处为显式加固）
-- 若要修改其认证插件为 native_password（不推荐，除非必须），可在此处 ALTER
-- GRANT ALL PRIVILEGES ON `your_app_db`.* TO 'your_user'@'%';

-- 3. 构建初始表逻辑 (仅作演示)
USE `test_database`;

-- 创建一个示例配置表
CREATE TABLE IF NOT EXISTS `system_settings` (
    `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `key` VARCHAR(64) NOT NULL UNIQUE COMMENT '配置键名',
    `value` TEXT COMMENT '配置内容',
    `description` VARCHAR(255) DEFAULT NULL COMMENT '描述',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统配置表';

-- 4. 插入初始种子数据
INSERT INTO `system_settings` (`key`, `value`, `description`) VALUES 
('app_name', 'Lunchbox Project', '项目名称'),
('allow_registration', 'true', '是否允许注册'),
('default_timezone', 'Asia/Shanghai', '系统默认时区');

-- 5. 针对 MySQL 8+ 建议的操作
-- 清刷权限（确保上述授权或改动立即生效）
FLUSH PRIVILEGES;

-- 脚本执行完毕
