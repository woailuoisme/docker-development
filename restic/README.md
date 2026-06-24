# restic backup

基于 [restic](https://restic.net/) + Alpine + dcron 的定时备份镜像，支持备份与恢复。

## 文件结构

```
restic/
├── Dockerfile
├── scripts/
│   ├── backup.sh       # 备份 / 恢复脚本
│   └── entrypoint.sh   # 容器启动、注册 cron
└── README.md
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `RESTIC_REPOSITORY` | `/repo` | 仓库路径，支持本地、S3、SFTP 等 |
| `RESTIC_PASSWORD` | `changeme` | 仓库加密密码 |
| `BACKUP_SOURCE` | `/data` | 备份源目录，多个路径用空格分隔 |
| `CRON_SCHEDULE` | `0 2 * * *` | cron 表达式，默认每天 02:00 |
| `RESTIC_KEEP_DAILY` | `7` | 保留最近 N 天快照 |
| `RESTIC_KEEP_WEEKLY` | `4` | 保留最近 N 周快照 |
| `RESTIC_KEEP_MONTHLY` | `6` | 保留最近 N 月快照 |
| `RUN_ON_STARTUP` | `false` | 容器启动时立即执行一次备份 |
| `RESTORE_TARGET` | `/restore` | 恢复目标目录 |
| `TZ` | `Asia/Shanghai` | 时区 |

## 快速开始

### docker-compose（本地仓库）

```yaml
services:
  restic:
    build: .
    environment:
      RESTIC_REPOSITORY: /repo
      RESTIC_PASSWORD: your-password
      BACKUP_SOURCE: /data
      CRON_SCHEDULE: "0 2 * * *"
      RUN_ON_STARTUP: "true"
    volumes:
      - /your/data:/data:ro
      - restic-repo:/repo
      - restic-log:/var/log/restic

volumes:
  restic-repo:
  restic-log:
```

### docker-compose（S3 仓库）

```yaml
services:
  restic:
    build: .
    environment:
      RESTIC_REPOSITORY: s3:https://s3.amazonaws.com/my-bucket/restic
      RESTIC_PASSWORD: your-password
      AWS_ACCESS_KEY_ID: your-key
      AWS_SECRET_ACCESS_KEY: your-secret
      BACKUP_SOURCE: /data
    volumes:
      - /your/data:/data:ro
      - restic-log:/var/log/restic

volumes:
  restic-log:
```

## 备份

cron 按 `CRON_SCHEDULE` 自动执行，也可手动触发：

```bash
docker exec <container> /scripts/backup.sh backup
```

## 恢复

```bash
# 恢复最新快照到 RESTORE_TARGET（默认 /restore）
docker exec <container> /scripts/backup.sh restore

# 恢复指定快照
docker exec <container> /scripts/backup.sh restore abc1234

# 指定恢复目标目录
docker exec -e RESTORE_TARGET=/data/recovered <container> /scripts/backup.sh restore
```

## 常用 restic 命令

```bash
# 列出所有快照
docker exec <container> restic snapshots

# 查看仓库状态
docker exec <container> restic stats

# 校验仓库数据完整性
docker exec <container> restic check

# 查看备份日志
docker exec <container> tail -f /var/log/restic/backup.log
```

## 构建

```bash
docker build -t restic-backup .

# 指定 restic 版本
docker build --build-arg RESTIC_VERSION=0.18.1 -t restic-backup .
```
