#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PostgreSQL 18 扩展初始化脚本 - 01-init-extensions.sh
# 职责：自动检测所有非系统模板数据库，统一加载核心扩展并配置环境
# 说明：不启用 ON_ERROR_STOP——pg_cron 仅允许在 cron.database_name (postgres)
#       库内创建，其余库该条语句失败后继续安装其他扩展，避免整体中断
# 时序扩展按需安装：TimescaleDB 会为每个装了扩展的库常驻一个 scheduler
#       后台进程并占用 worker 槽位，故仅在 TIMESCALE_DATABASES 声明的库中安装，
#       避免空装库挤占 max_worker_processes (当前容量规划 24)
# =============================================================================

# 需要安装 TimescaleDB 的库（空格分隔，可在 compose environment 覆盖）
TIMESCALE_DATABASES="${TIMESCALE_DATABASES:-lunchbox}"

# 动态查询所有非模板数据库列表（排除 template0, template1 等系统库）
DATABASES=$(psql -XtA -c "SELECT datname FROM pg_database WHERE datistemplate = false;" --username "$POSTGRES_USER" --dbname "postgres")

for db in $DATABASES; do
	echo "Initializing extensions for database: ${db}"

	# 时序特化扩展仅装进声明的库 (Hypertable / 连续聚合 / 数据压缩)
	if [[ " $TIMESCALE_DATABASES " == *" $db "* ]]; then
		psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<- 'EOSQL'
			CREATE EXTENSION IF NOT EXISTS timescaledb;
		EOSQL
		echo "TimescaleDB extension installed for database: ${db}"
	fi

	psql --username "$POSTGRES_USER" --dbname "$db" <<- 'EOSQL'
		-- -----------------------------------------------------------------------------
		-- 一、核心特化扩展 (GIS / AI 向量 / 定时调度)
		-- -----------------------------------------------------------------------------

		-- 1. PostGIS: 空间地理信息系统扩展
		CREATE EXTENSION IF NOT EXISTS postgis;

		-- 2. pgvector: 向量数据库基础扩展 (HNSW / IVFFlat)
		CREATE EXTENSION IF NOT EXISTS vector;

		-- 3. pg_cron: 数据库内定时任务调度器
		CREATE EXTENSION IF NOT EXISTS pg_cron;

		-- -----------------------------------------------------------------------------
		-- 二、性能监控与缓存预热扩展
		-- -----------------------------------------------------------------------------

		-- 4. pg_stat_statements: SQL 查询执行性能分析
		CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

		-- 5. pg_prewarm: 数据库缓存预热
		CREATE EXTENSION IF NOT EXISTS pg_prewarm;

		-- -----------------------------------------------------------------------------
		-- 三、文本检索与高级索引加速扩展
		-- -----------------------------------------------------------------------------

		-- 6. citext: 大小写不敏感文本类型
		CREATE EXTENSION IF NOT EXISTS citext;

		-- 7. pg_trgm: 三元组模糊匹配与相似度索引
		CREATE EXTENSION IF NOT EXISTS pg_trgm;

		-- 8. btree_gin: 标量类型的 GIN 复合索引
		CREATE EXTENSION IF NOT EXISTS btree_gin;

		-- 9. btree_gist: 标量类型的 GiST 排他与范围索引
		CREATE EXTENSION IF NOT EXISTS btree_gist;

		-- 10. ltree: 树状/层级路径数据类型
		CREATE EXTENSION IF NOT EXISTS ltree;

		-- -----------------------------------------------------------------------------
		-- 四、在线维护扩展 (表膨胀治理)
		-- -----------------------------------------------------------------------------

		-- 11. pg_repack: 在线重组表/索引膨胀 (VACUUM FULL 替代方案，不持有长期独占锁)
		CREATE EXTENSION IF NOT EXISTS pg_repack;
	EOSQL

	echo "Extensions initialized successfully for database: ${db}"
done

echo "All databases extension initialization completed."
