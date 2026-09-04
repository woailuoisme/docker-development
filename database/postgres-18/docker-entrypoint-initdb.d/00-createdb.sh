#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PostgreSQL 数据库初始化脚本 - 00-createdb.sh
# 职责：负责“行政逻辑”——创建额外业务数据库、用户角色与分配权限
# 规范：扩展安装由 01-*.sh 统一处理，表结构由 02-*.sh 统一处理
# =============================================================================

function create_db_if_not_exists() {
	local db=$1
	if [ "$(psql -XtA -c "SELECT 1 FROM pg_database WHERE datname='$db'" --username "$POSTGRES_USER" --dbname "postgres")" != '1' ]; then
		echo "Creating database: ${db}"
		psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<- EOSQL
			CREATE DATABASE ${db};
			GRANT ALL PRIVILEGES ON DATABASE ${db} TO "$POSTGRES_USER";
		EOSQL
		echo "Database ${db} created successfully."
	else
		echo "Database ${db} already exists, skipping creation."
	fi
}

# 默认数据库由 POSTGRES_DB 环境变量指定（PostgreSQL 官方镜像已自动创建）
# 如果需要独立的业务数据库（如 lunchbox），在此按需创建：
if [ "${POSTGRES_DB:-}" != "lunchbox" ]; then
	create_db_if_not_exists "lunchbox"
fi

# 在此可以继续按需添加其他业务库，例如：
# create_db_if_not_exists "shop"
# create_db_if_not_exists "authelia"
create_db_if_not_exists "zitadel"
create_db_if_not_exists "chatwoot"

echo "Database administrator tasks completed."
