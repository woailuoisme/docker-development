#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PostgreSQL 18 扩展初始化脚本 - 01-init-extensions.sh
# 职责：自动检测所有非系统模板数据库，统一加载核心扩展并配置环境
# =============================================================================

# 动态查询所有非模板数据库列表（排除 template0, template1 等系统库）
DATABASES=$(psql -XtA -c "SELECT datname FROM pg_database WHERE datistemplate = false;" --username "$POSTGRES_USER" --dbname "postgres")

for db in $DATABASES; do
	echo "Initializing extensions for database: ${db}"

	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<- 'EOSQL'
		-- -----------------------------------------------------------------------------
		-- 一、核心特化扩展 (GIS / AI 向量 / 图数据库 / 定时调度)
		-- -----------------------------------------------------------------------------

		-- 1. PostGIS: 空间地理信息系统扩展
		CREATE EXTENSION IF NOT EXISTS postgis;

		-- 2. pgvector: 向量数据库基础扩展 (HNSW / IVFFlat)
		CREATE EXTENSION IF NOT EXISTS vector;

		-- 3. pgvectorscale: Timescale 向量加速扩展 (DiskANN + SBQ)
		CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;

		-- 4. Apache AGE: openCypher 图数据库扩展
		CREATE EXTENSION IF NOT EXISTS age;

		-- 5. pg_cron: 数据库内定时任务调度器
		CREATE EXTENSION IF NOT EXISTS pg_cron;

		-- -----------------------------------------------------------------------------
		-- 二、性能监控与缓存预热扩展
		-- -----------------------------------------------------------------------------

		-- 6. pg_stat_statements: SQL 查询执行性能分析
		CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

		-- 7. pg_prewarm: 数据库缓存预热
		CREATE EXTENSION IF NOT EXISTS pg_prewarm;

		-- -----------------------------------------------------------------------------
		-- 三、文本检索与高级索引加速扩展
		-- -----------------------------------------------------------------------------

		-- 8. citext: 大小写不敏感文本类型
		CREATE EXTENSION IF NOT EXISTS citext;

		-- 9. pg_trgm: 三元组模糊匹配与相似度索引
		CREATE EXTENSION IF NOT EXISTS pg_trgm;

		-- 10. btree_gin: 标量类型的 GIN 复合索引
		CREATE EXTENSION IF NOT EXISTS btree_gin;

		-- 11. btree_gist: 标量类型的 GiST 排他与范围索引
		CREATE EXTENSION IF NOT EXISTS btree_gist;

		-- 12. ltree: 树状/层级路径数据类型
		CREATE EXTENSION IF NOT EXISTS ltree;
	EOSQL

	# 针对当前数据库配置 Apache AGE search_path
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<- EOSQL
		ALTER DATABASE "$db" SET search_path = ag_catalog, "\$user", public;
	EOSQL

	echo "Extensions initialized successfully for database: ${db}"
done

echo "All databases extension initialization completed."
