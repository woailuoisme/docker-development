#!/usr/bin/env bash

# PostgreSQL 扩展说明：
# 1. postgis (核心地理信息系统驱动):
#    对应安装包：apt: postgresql-18-postgis-3
#    底层依赖库：libgeos-c1v5, libproj25, libgdal32
#    作用：支持地理空间对象（点、线、面），引入 GEOMETRY 和 GEOGRAPHY 类型。
#
# 2. postgis_topology (拓扑地理):
#    对应安装包：apt: postgresql-18-postgis-3 (已包含)
#    作用：维护地理对象间的共享关系（边、面连接），防止缝隙或重叠。
#
# 3. postgis_raster (栅格数据/影像):
#    对应安装包：apt: postgresql-18-postgis-3 (已包含)
#    作用：支持在数据库中存储与查询像素矩阵数据（如 TIFF, JPG）。
#
# 4. fuzzystrmatch (模糊字符串匹配):
#    对应安装包：PostgreSQL 内置
#    作用：提供相似度（Levenshtein）或发音匹配（Soundex）算法。
#
# 5. uuid-ossp (UUID 产生器):
#    对应安装包：PostgreSQL 内置
#    作用：提供多种算法生成通用唯一识别码。
#
# 6. vector (向量数据库):
#    对应安装包：apt: postgresql-18-pgvector
#    作用：支持高维向量存储与相似度检索，用于 AI 语义搜索。
#
# 7. timescaledb (时序数据库):
#    对应安装包：apt: postgresql-18-timescaledb
#    作用：通过超表自动分区，优化时间序列数据的存储与查询。
#
# 8. pg_cron (定时任务):
#    对应安装包：apt: postgresql-18-cron
#    作用：在数据库内部通过 cron 语法调度 SQL 任务。
#
# 9. ai (pgai):
#    来源：源码编译 (Timescale)
#    作用：将 AI 功能（搜索、集成、向量化）直接引入 PostgreSQL。
#
# 10. vectorscale (pgvectorscale):
#    来源：源码编译 (Timescale)
#    作用：基于 DiskANN 算法的高性能向量索引优化。


#
# Copy createdb.sh.example to createdb.sh
# then uncomment then set database name and username to create you need databases
#
# example: .env POSTGRES_USER=appuser and need db name is myshop_db
#
#    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
#        CREATE USER myuser WITH PASSWORD 'mypassword';
#        CREATE DATABASE myshop_db;
#        GRANT ALL PRIVILEGES ON DATABASE myshop_db TO myuser;
#    EOSQL
#
# this sh script will auto run when the postgres container starts and the $DATA_PATH_HOST/postgres not found.
#
#

#psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
#	CREATE USER docker;
#	CREATE DATABASE docker;
#	GRANT ALL PRIVILEGES ON DATABASE docker TO docker;
#EOSQL

# 创建 lunchbox 数据库
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE lunchbox;
    GRANT ALL PRIVILEGES ON DATABASE lunchbox TO "$POSTGRES_USER";
EOSQL

# 为 lunchbox 数据库启用扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "lunchbox" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- 提供 UUID 生成功能
    CREATE EXTENSION IF NOT EXISTS "vector";         -- 对应 apt: postgresql-18-pgvector (向量检索)
    CREATE EXTENSION IF NOT EXISTS "postgis";        -- 对应 apt: postgresql-18-postgis-3 (地理空间支持)
    CREATE EXTENSION IF NOT EXISTS "postgis_topology";-- 依赖 postgis (拓扑地理支持)
    CREATE EXTENSION IF NOT EXISTS "postgis_raster";  -- 依赖 postgis (栅格数据支持)
    CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch";  -- 提供模糊字符串匹配算法
    CREATE EXTENSION IF NOT EXISTS "timescaledb";    -- 对应 apt: postgresql-18-timescaledb-2 (时序数据库支持)
EOSQL
#
## 创建 shop 数据库
#psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
#    CREATE DATABASE shop;
#    GRANT ALL PRIVILEGES ON DATABASE shop TO $POSTGRES_USER;
#EOSQL
#
## 为 shop 数据库启用 PostGIS 扩展
#psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "shop" <<-EOSQL
#    CREATE EXTENSION IF NOT EXISTS postgis;
#    CREATE EXTENSION IF NOT EXISTS postgis_topology;
#    CREATE EXTENSION IF NOT EXISTS postgis_raster;
#    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
#EOSQL
#
## 创建 domost 数据库
#psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
#    CREATE DATABASE domost;
#    GRANT ALL PRIVILEGES ON DATABASE domost TO $POSTGRES_USER;
#EOSQL
#
## 创建 authelia 数据库
#psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
#    CREATE DATABASE authelia;
#    GRANT ALL PRIVILEGES ON DATABASE authelia TO $POSTGRES_USER;
#EOSQL

# 注意：默认数据库 ($POSTGRES_DB) 的 PostGIS 扩展已在前面安装
# 这里不再重复安装
