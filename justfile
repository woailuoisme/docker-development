set dotenv-load := true

# 路径定义
caddy_root_cert := "./data/caddy/pki/authorities/local/root.crt"

# 快捷别名
alias fmt := fmt-md
alias validate-docker-compose := lint-compose

# 运行全量代码与配置检测
lint: lint-sh lint-docker lint-caddy lint-compose lint-actions lint-md

# 格式化 Markdown
fmt-md:
    rumdl fmt

# 检查 Markdown 文档
lint-md:
    rumdl check .

# 检查 Shell 脚本
lint-sh:
    fd --type file --extension sh --exclude data --exec-batch shellcheck --severity=warning

# 检查 Dockerfile
lint-docker:
    fd --type file '^Dockerfile.*$' --exclude data --exec-batch hadolint

# 检查 GitHub Actions 工作流
lint-actions:
    actionlint

# 验证 Docker Compose 配置
lint-compose:
    docker-compose config >/dev/null

# 验证 Caddy 配置文件
lint-caddy:
    docker-compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

# 测试 Caddy 代理
test-proxy:
    ./test_caddy_proxy.sh

# 安装 Caddy 根证书到 macOS 系统钥匙串
trust-cert:
    #!/usr/bin/env bash
    if [ -f "{{ caddy_root_cert }}" ]; then
        echo "正在安装 Caddy 根证书到 macOS 系统钥匙串..."
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "{{ caddy_root_cert }}"
        echo "证书安装成功！"
    else
        echo "错误: 找不到证书文件 {{ caddy_root_cert }}"
        echo "请确保 Caddy 服务已经启动并生成了证书。"
    fi

# 手动在线重组指定表的膨胀 (例如: just pg-repack lunchbox users)
pg-repack db table:
    docker exec postgres pg_repack --username "${POSTGRES_USER}" --dbname "{{ db }}" --table "{{ table }}" --wait-timeout 60

# 手动触发全库膨胀巡检与在线重组 (定时任务为每月 1 日/16 日 03:00；超表由 TimescaleDB 压缩/保留策略治理)
pg-repack-all:
	docker exec postgres psql --username "${POSTGRES_USER}" --dbname postgres -c "SELECT public.repack_bloated_tables();"

# 查看 pgBackRest 备份清单与 stanza 状态
pg-backup-info:
	docker exec pgbackrest pgbackrest --stanza=main info

# 手动触发一次全量备份 (日常由容器内调度器每日 03:00 自动执行)
pg-backup-now:
	docker exec pgbackrest pgbackrest --stanza=main --type=full backup

# 恢复演练：从仓库恢复最新全量到隔离目录并用临时 PostgreSQL 验证数据可用 (不触碰生产数据)
pg-backup-restore-test:
	#!/usr/bin/env bash
	set -euo pipefail
	RESTORE_DIR="${DATA_PATH}postgres18/restore-test"
	rm -rf "${RESTORE_DIR}"
	mkdir -p "${RESTORE_DIR}/data"
	echo "→ 从备份仓库恢复最新全量备份..."
	docker exec pgbackrest pgbackrest --stanza=main \
	  --pg1-path="${RESTORE_DIR}/data" \
	  --db-include="${POSTGRES_DB}" \
	  --delta restore
	echo "→ 启动临时 PostgreSQL 验证恢复数据..."
	docker run --rm -d --name pg-restore-test \
	  -v "${RESTORE_DIR}/data:/var/lib/postgresql/data" \
	  -e POSTGRES_HOST_AUTH_METHOD=trust \
	  postgres:18.6-trixie >/dev/null
	sleep 10
	docker exec pg-restore-test psql --username postgres --dbname "${POSTGRES_DB}" \
	  -c "SELECT count(*) AS table_count FROM information_schema.tables WHERE table_schema='public';"
	docker stop pg-restore-test >/dev/null
	rm -rf "${RESTORE_DIR}"
	echo "✔ 恢复演练通过：备份数据完整可用"
