#!/usr/bin/env bash

# =============================================================================
# PostgreSQL 数据库初始化脚本 (.sh)
# 职责：负责“行政逻辑”——创建数据库、创建用户、分配权限
# 注意：业务级的插件安装与表结构定义应放在 01-*.sql 和 02-*.sql 中
# =============================================================================

set -e

# 1. 创建额外的业务数据库 (如果需要独立于默认库)
# 默认库由 POSTGRES_DB 环境变量指定，Docker 会自动创建它
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- 创建 lunchbox 数据库
    CREATE DATABASE lunchbox;
    GRANT ALL PRIVILEGES ON DATABASE lunchbox TO "$POSTGRES_USER";

    -- 在此可以继续添加其他业务库，例如：
    -- CREATE DATABASE shop;
    -- CREATE DATABASE authelia;
EOSQL

# 2. 为额外的数据库安装基础插件 (可选)
# 如果业务逻辑都在默认库，由 01-init-extensions.sql 处理即可
# 如果 lunchbox 库也需要插件，可以统一在这里执行一次
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "lunchbox" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "timescaledb";
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "postgis";
EOSQL

echo "Database administrator tasks completed."
