-- =============================================================================
-- PostgreSQL 18 扩展初始化脚本
-- 自动创建常用扩展，避免手动执行 CREATE EXTENSION
-- =============================================================================

-- 核心扩展
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 性能监控（内置扩展）
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 内置实用扩展
CREATE EXTENSION IF NOT EXISTS btree_gin;      -- GIN 索引支持 B-tree 类型
CREATE EXTENSION IF NOT EXISTS btree_gist;     -- GiST 索引支持 B-tree 类型
CREATE EXTENSION IF NOT EXISTS pg_trgm;        -- 三元组相似度搜索（模糊匹配）
CREATE EXTENSION IF NOT EXISTS pgcrypto;       -- 加密函数
CREATE EXTENSION IF NOT EXISTS uuid-ossp;      -- UUID 生成
CREATE EXTENSION IF NOT EXISTS hstore;         -- 键值对存储

-- 提示信息
DO $$
BEGIN
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'PostgreSQL 18 扩展初始化完成！';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE '已启用扩展：';
    RAISE NOTICE '  核心扩展：';
    RAISE NOTICE '    - timescaledb (时序数据)';
    RAISE NOTICE '    - postgis (地理空间)';
    RAISE NOTICE '    - pgvector (向量搜索)';
    RAISE NOTICE '    - pg_cron (定时任务)';
    RAISE NOTICE '  性能监控：';
    RAISE NOTICE '    - pg_stat_statements (SQL 统计)';
    RAISE NOTICE '  实用工具：';
    RAISE NOTICE '    - pg_trgm (模糊搜索)';
    RAISE NOTICE '    - pgcrypto (加密)';
    RAISE NOTICE '    - uuid-ossp (UUID)';
    RAISE NOTICE '    - hstore (键值对)';
    RAISE NOTICE '    - btree_gin/btree_gist (索引增强)';
    RAISE NOTICE '=============================================================================';
END $$;
