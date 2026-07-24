#!/usr/bin/env bash

# =============================================================================
# PostgreSQL 数据库初始化脚本 (.sh)
# 职责：负责“行政逻辑”——创建数据库、创建用户、分配权限
# 注意：业务级的插件安装与表结构定义应放在 01-*.sql 和 02-*.sql 中
# =============================================================================

set -e

# 1. 创建额外的业务数据库 (如果需要独立于默认库)
# 默认库由 POSTGRES_DB 环境变量指定，Docker 会自动创建它
# 如果 POSTGRES_DB 已经是 lunchbox，则不需要手动创建

function create_db_if_not_exists() {
	local db=$1
	if [ "$(psql -XtA -c "SELECT 1 FROM pg_database WHERE datname='$db'" --username "$POSTGRES_USER" --dbname "postgres")" != '1' ]; then
		echo "Creating database: $db"
		psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<- EOSQL
			      CREATE DATABASE $db;
			      GRANT ALL PRIVILEGES ON DATABASE $db TO "$POSTGRES_USER";
		EOSQL
	else
		echo "Database $db already exists, skipping creation."
	fi
}

# 只有当 lunchbox 不是默认数据库时，才尝试创建它
if [ "$POSTGRES_DB" != "lunchbox" ]; then
	create_db_if_not_exists "lunchbox"
fi

# 在此可以继续添加其他业务库，例如：
# create_db_if_not_exists "shop"
# create_db_if_not_exists "authelia"

# 2. 为 lunchbox 数据库安装基础插件 (可选)
# 职责：确保 lunchbox 库始终拥有核心扩展。
# 如果 lunchbox 是默认库 (POSTGRES_DB)，01-init-extensions.sql 也会覆盖它。
echo "Initializing extensions for database: lunchbox"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "lunchbox" <<- EOSQL
	    CREATE EXTENSION IF NOT EXISTS "timescaledb";
	    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
	    CREATE EXTENSION IF NOT EXISTS "postgis";
EOSQL

echo "Database administrator tasks completed."
