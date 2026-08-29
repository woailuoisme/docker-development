#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# pg_repack 定时维护初始化脚本 - 03-init-repack-cron.sh
# 职责：注册 pg_cron 定时任务，自动巡检并在线重组全库膨胀表
# 策略：
#   1. 巡检范围：所有非模板且可连接的业务数据库（经 dblink 跨库执行）
#   2. 膨胀判定：死元组 > 100000 且占比 > 20%（按体积降序优先处理大表）
#   3. 调度窗口：每月 1 日、16 日 03:00（低峰时段）
#   4. 无主键/唯一索引的表与 TimescaleDB 超表 (Hypertable) 无法重组；
#      60 秒内抢不到锁则跳过，均记录日志不中断
# 手动全库巡检：psql -c "SELECT public.repack_bloated_tables();"
# 单表在线重组：宿主机执行 `just pg-repack <库名> <表名>`（CLI 通道，可控锁等待）
# =============================================================================

# pg_cron 宿主库与 postgresql.conf 的 cron.database_name 保持一致
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<- 'EOSQL'
	-- pg_cron 宿主库需要 dblink 支持跨库巡检（contrib 内置模块）
	CREATE EXTENSION IF NOT EXISTS dblink;

	-- 全库膨胀巡检与在线重组函数
	CREATE OR REPLACE FUNCTION public.repack_bloated_tables(
		dead_tup_min   bigint  DEFAULT 100000,
		dead_ratio_min numeric DEFAULT 0.2
	) RETURNS void LANGUAGE plpgsql AS $$
	DECLARE
		db   record;
		conn text;
		tbl  record;
	BEGIN
		FOR db IN
			SELECT datname FROM pg_database
			WHERE datistemplate = false AND datallowconn
		LOOP
			conn := format('dbname=%I', db.datname);
			FOR tbl IN
				SELECT *
				FROM dblink(
					conn,
					format(
						'SELECT schemaname, tablename
						 FROM pg_stat_user_tables
						 WHERE n_dead_tup > %s
						   AND (n_dead_tup::numeric / greatest(n_live_tup + n_dead_tup, 1)) > %s
						 ORDER BY pg_total_relation_size(relid) DESC',
						dead_tup_min, dead_ratio_min
					)
				) AS t(schemaname text, tablename text)
			LOOP
				BEGIN
					PERFORM dblink_exec(
						conn,
						format('SELECT repack.apply(%L)', format('%I.%I', tbl.schemaname, tbl.tablename))
					);
					RAISE NOTICE '[pg_repack] %.%.% repacked', db.datname, tbl.schemaname, tbl.tablename;
				EXCEPTION WHEN OTHERS THEN
					RAISE NOTICE '[pg_repack] skip %.%.%: %', db.datname, tbl.schemaname, tbl.tablename, SQLERRM;
				END;
			END LOOP;
		END LOOP;
	END
	$$;

	-- 重组大表耗时长：放开语句超时；抢锁 60 秒未果即跳过，避免阻塞业务
	ALTER FUNCTION public.repack_bloated_tables(bigint, numeric) SET statement_timeout = 0;
	ALTER FUNCTION public.repack_bloated_tables(bigint, numeric) SET lock_timeout = '60s';

	-- 幂等注册定时任务（先清理同名旧任务）
	SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'repack-bloated-tables';
	SELECT cron.schedule_in_database(
		'repack-bloated-tables',
		'0 3 1,16 * *',
		'SELECT public.repack_bloated_tables()',
		'postgres'
	);
EOSQL

echo "pg_repack maintenance job registered (schedule: 0 3 1,16 * *)."
