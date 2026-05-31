# Rclone 备份与管理工具链

本目录保存 Rclone 的容器化调用脚本与统一配置文件，用于对本地 Garage 容器进行管理以及一键异地冷备份（如备份至阿里云 OSS / Cloudflare R2）。

## 1. 配置文件解析 (`rclone.conf`)

此目录下的 `rclone.conf` 为**合并统一版配置**，定义了以下关键远程源（Remote）：

- **`garage`**：容器内部专用源（连接终结点为 `http://garage:3900`）。在容器内运行的 Rclone（例如使用 `rclone.sh` 时）默认应使用此源。
- **`garage-local`**：宿主机本地调试源（连接终结点为 `http://127.0.0.1:3900`）。如果您在宿主机上直接安装了 rclone 二进制，请指定此源进行本地连接。
- **`ali-oss`** / **`cloudflare-r2`**：第三方公网冷备份源。**使用前请务必修改配置文件中的 `access_key_id`、`secret_access_key` 及 `endpoint`（R2 需填 Account ID）**。

---

## 2. 脚本使用说明

在运行脚本前，请确保在当前目录下，或者在父目录调用时带上正确的路径前缀。以下示例以在 **当前 `rclone/` 子目录** 运行为准：

### ① 容器化通用指令入口 (`rclone.sh`)

该脚本无需在宿主机安装 Rclone，通过自动下载并运行官方 Docker 镜像进行操作：

```bash
# 列出存储桶下的文件
bash rclone.sh ls garage:default

# 从本地复制文件到 S3 存储桶
bash rclone.sh copy ./local-file.txt garage:default/

# 将本地目录增量同步到 S3 存储桶备份区
bash rclone.sh sync ./local-dir garage:default/backup/

# 删除存储桶内的指定文件
bash rclone.sh delete garage:default/old-file.txt
```

> **设计说明**：脚本内部采用了条件挂载机制。只有在运行 `copy` / `sync` 时，才会挂载宿主机的当前工作目录（映射至容器的 `/work` 目录），日常的 `ls` 和 `delete` 不会有任何挂载开销。

### ② 一键远端冷同步工具 (`to-remote.sh`)

用于直接将本地 Garage 中的存储桶数据上传/镜像至阿里云 OSS 或 Cloudflare R2 进行灾备：

```bash
# 【复制模式】将本地默认桶数据复制到阿里云 OSS 的 default 桶中（仅追加）
bash to-remote.sh copy ali-oss garage:default default
# 【同步模式】完全镜像同步本地数据至 Cloudflare R2（注意：云端多余文件会被删除！）
bash to-remote.sh sync r2 garage:default default
```

#### 参数快捷缩写映射表
* **操作类型**：`copy` / `cp` （复制）、`sync` / `sy` （镜像同步）。
* **目标云厂商**：`ali-oss` / `ali` （阿里云）、`cloudflare-r2` / `r2` （Cloudflare）。
