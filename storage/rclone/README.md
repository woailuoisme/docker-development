# rclone

这个目录保存 rclone 的通用配置和容器化调用方式。

## 文件说明

- `docker-compose.yml`：rclone 容器编排
- `rclone.sh`：统一入口脚本，支持 `ls`、`copy`、`sync`、`delete`
- `rclone.conf`：宿主机使用的 rclone 配置
- `rclone.docker.conf`：Docker 容器内使用的 rclone 配置
- `to-remote.sh`：把源复制或同步到 `ali-oss` / `cloudflare-r2`

## 说明

- `rclone.conf` 的 `garage` remote 使用 `http://127.0.0.1:3900`
- `rclone.docker.conf` 的 `garage` remote 使用 `http://garage:3900`
- `ali-oss` 和 `cloudflare-r2` 已同步写入两份配置，除了 `garage` 以外的 remote 可以保持一致

## 用法

```bash
bash rclone/rclone.sh ls garage:default
bash rclone/rclone.sh copy ./local-file garage:default/
bash rclone/rclone.sh sync ./local-dir garage:default/backup/
bash rclone/rclone.sh delete garage:default/old-file.txt
```

## 目标云同步

```bash
bash rclone/to-remote.sh copy ali-oss garage:default default
bash rclone/to-remote.sh copy r2 garage:default default
bash rclone/to-remote.sh sync ali-oss garage:default default
bash rclone/to-remote.sh sync r2 garage:default default
```

短写也支持：

```bash
bash rclone/to-remote.sh cp ali garage:default default
bash rclone/to-remote.sh sy r2 garage:default default
```

可用别名：

- 操作：`copy` / `sync` / `cp` / `sy`
- 目标：`ali-oss` / `ali` / `r2` / `cloudflare-r2`

## `copy` 和 `sync` 的区别

- 想备份、追加、保守操作，用 `copy`
- 想做镜像、保持完全一致，用 `sync`

## 容器版

如果你想直接在 Docker 里运行 rclone，可以使用：

```bash
docker compose -f rclone/docker-compose.yml run --rm rclone lsd garage:
```
