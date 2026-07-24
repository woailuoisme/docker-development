-- =============================================================================
-- PostgreSQL 18 扩展初始化脚本
-- 自动创建常用扩展，避免手动执行 CREATE EXTENSION
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 性能监控（内置扩展）
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 内置实用扩展
CREATE EXTENSION IF NOT EXISTS btree_gin;      -- GIN 索引支持 B-tree 类型
CREATE EXTENSION IF NOT EXISTS btree_gist;     -- GiST 索引支持 B-tree 类型
CREATE EXTENSION IF NOT EXISTS pg_trgm;        -- 三元组相似度搜索（模糊匹配）
CREATE EXTENSION IF NOT EXISTS pgcrypto;       -- 加密函数
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID 生成
CREATE EXTENSION IF NOT EXISTS hstore;         -- 键值对存储

-- 提示信息
DO $$
BEGIN
    RAISE NOTICE 'PostgreSQL 18 扩展初始化完成 (timescaledb, postgis, vector, pg_cron, pg_stat_statements 等)';
END $$;
