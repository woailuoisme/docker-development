#!/usr/bin/env bash

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

# 创建 lunchbox 数据库并启用 PostGIS 扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE lunchbox;
    GRANT ALL PRIVILEGES ON DATABASE lunchbox TO $POSTGRES_USER;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "lunchbox" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS vector;
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;
    CREATE EXTENSION IF NOT EXISTS postgis_raster;
EOSQL

# 创建 shop 数据库并启用 PostGIS 扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE shop;
    GRANT ALL PRIVILEGES ON DATABASE shop TO $POSTGRES_USER;
EOSQL

# SELECT uuid_generate_v4(); -- 生成随机UUID

#pg_trgm（官方内置）
#核心用途：基于三元组（trigram）的模糊匹配，支持相似度计算、模糊查询、拼音 / 英文模糊搜索，比 LIKE % xxx% 效率高 10 倍以上。
#使用场景：商品名称模糊搜索、用户昵称匹配、地址模糊查询。
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "shop" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS uuid-ossp;
    CREATE EXTENSION IF NOT EXISTS vector;
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;
    CREATE EXTENSION IF NOT EXISTS postgis_raster;
EOSQL

# 创建 domost 数据库并启用 PostGIS 扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE domost;
    GRANT ALL PRIVILEGES ON DATABASE domost TO $POSTGRES_USER;
EOSQL

# 创建 authelia 数据库（不需要 PostGIS）
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE authelia;
    GRANT ALL PRIVILEGES ON DATABASE authelia TO $POSTGRES_USER;
EOSQL
