# Lunchbox 数据备份恢复脚本使用说明

## 概述

`backup.sh` 是一个用于备份和恢复 Lunchbox 项目数据的脚本。它支持多种压缩算法，自动清理旧备份，并提供安全的数据恢复功能。

## 脚本位置

```
lunchbox/scripts/backup.sh
```

## 基本用法

```bash
# 显示帮助信息
./scripts/backup.sh help

# 创建备份（使用默认gzip压缩）
./scripts/backup.sh backup

# 列出所有可用备份
./scripts/backup.sh list

# 从最新备份恢复数据
./scripts/backup.sh restore
```

## 命令详解

### 1. 备份命令 (backup)

创建数据目录的备份，默认使用 gzip 压缩。

**语法：**
```bash
./scripts/backup.sh backup [选项]
```

**选项：**
- `-t, --type TYPE` - 压缩算法类型：`gzip`、`bzip2`、`xz`（默认：`gzip`）
- `-c, --no-compress` - 不压缩备份文件
- `-m, --max N` - 保留的最大备份数量（默认：30）

**示例：**
```bash
# 使用默认gzip压缩
./scripts/backup.sh backup

# 使用xz压缩（压缩率最高，速度最慢）
./scripts/backup.sh backup -t xz

# 使用bzip2压缩
./scripts/backup.sh backup -t bzip2

# 不压缩备份
./scripts/backup.sh backup -c

# 只保留最近10个备份
./scripts/backup.sh backup -m 10
```

### 2. 恢复命令 (restore)

从备份文件恢复数据到 data 目录。

**语法：**
```bash
./scripts/backup.sh restore [选项]
```

**选项：**
- `-f, --file FILE` - 指定备份文件路径（默认：使用最新备份）
- `-y, --yes` - 自动确认恢复操作（跳过确认提示）

**示例：**
```bash
# 从最新备份恢复（需要确认）
./scripts/backup.sh restore

# 从指定备份文件恢复
./scripts/backup.sh restore -f backup/backup_20251205_103033.tar.gz

# 自动确认恢复（跳过确认提示）
./scripts/backup.sh restore -y
```

### 3. 列表命令 (list)

列出所有可用的备份文件。

**语法：**
```bash
./scripts/backup.sh list
```

**输出示例：**
```
2025-12-05 10:33:00 [INFO] 可用备份文件 (4 个):
========================================
文件名                           大小     修改时间
----------------------------------------
backup_20251205_103250.tar          393M       2025-12-05 10:32:54
backup_20251205_103133.tar.xz        59M       2025-12-05 10:32:44
backup_20251205_103113.tar.bz2      113M       2025-12-05 10:31:33
backup_20251205_103033.tar.gz       128M       2025-12-05 10:30:44
========================================
```

## 压缩算法比较

| 算法 | 速度 | 压缩率 | 备份大小（377MB数据） | 适用场景 |
|------|------|--------|----------------------|----------|
| **gzip** | 快 | 中等 | 约 128MB | 日常使用，平衡速度与压缩率 |
| **bzip2** | 中等 | 较好 | 约 113MB | 需要较好压缩率，可接受稍慢速度 |
| **xz** | 慢 | 最高 | 约 59MB | 需要最大压缩率，存储空间有限 |
| **不压缩** | 最快 | 无 | 约 393MB | 需要快速备份，或频繁恢复 |

**推荐选择：**
- **日常备份**: 使用 `gzip`（默认）
- **节省存储空间**: 使用 `xz`
- **快速备份/恢复**: 使用 `-c` 选项（不压缩）

## 文件结构

### 备份文件命名规则
```
backup_YYYYMMDD_HHMMSS.tar[.扩展名]
```

**示例：**
- `backup_20251205_103033.tar.gz` - gzip压缩
- `backup_20251205_103113.tar.bz2` - bzip2压缩
- `backup_20251205_103133.tar.xz` - xz压缩
- `backup_20251205_103250.tar` - 未压缩

### 目录结构
```
lunchbox/
├── scripts/
│   ├── backup.sh      # 备份脚本
│   └── backup.md      # 本文档
├── data/              # 数据目录（备份源）
├── backup/            # 备份文件存储目录
└── logs/              # 日志文件目录
```

## 安全注意事项

### 恢复操作警告
恢复操作会 **覆盖** 目标目录中的所有现有数据。脚本提供以下安全机制：

1. **确认提示**：默认需要用户确认
2. **自动备份**：恢复前会自动备份现有数据到 `before_restore_*.tar.gz`
3. **详细日志**：所有操作记录到日志文件

### 数据保护建议
1. **定期备份**：建议设置定时任务定期备份
2. **异地备份**：重要数据建议复制到其他位置
3. **测试恢复**：定期测试恢复流程确保备份有效

## 自动化备份

### 使用 crontab 定时备份
```bash
# 编辑 crontab
crontab -e

# 添加以下行（每天凌晨2点备份）
0 2 * * * cd /Users/seaside/Projects/docker/lunchbox && ./scripts/backup.sh backup -t xz

# 添加以下行（每周日凌晨3点备份并只保留10个）
0 3 * * 0 cd /Users/seaside/Projects/docker/lunchbox && ./scripts/backup.sh backup -t gzip -m 10
```

### 备份保留策略
脚本自动清理旧备份，只保留最新的 `N` 个文件（默认30个）。可以通过 `-m` 选项调整。

## 故障排除

### 常见问题

1. **权限问题**
   ```bash
   # 添加执行权限
   chmod +x scripts/backup.sh
   ```

2. **缺少工具**
   ```bash
   # 安装必需工具（macOS）
   brew install gzip bzip2 xz
   
   # Ubuntu/Debian
   sudo apt-get install tar gzip bzip2 xz-utils
   ```

3. **磁盘空间不足**
   - 检查备份目录空间：`df -h backup/`
   - 减少保留备份数量：`./scripts/backup.sh backup -m 10`
   - 使用更高压缩率：`./scripts/backup.sh backup -t xz`

### 日志文件
所有操作记录到日志文件：
```
logs/backup_YYYYMMDD.log
```

查看最新日志：
```bash
tail -f logs/backup_$(date +%Y%m%d).log
```

## 高级用法

### 组合使用示例
```bash
# 1. 创建压缩备份并立即列出
./scripts/backup.sh backup -t xz && ./scripts/backup.sh list

# 2. 备份后检查文件大小
./scripts/backup.sh backup && ls -lh backup/ | tail -5

# 3. 从特定时间点的备份恢复
./scripts/backup.sh list
./scripts/backup.sh restore -f backup/backup_20251205_103033.tar.gz
```

### 环境变量（如需自定义）
```bash
# 临时修改备份目录
BACKUP_DIR=/path/to/backup ./scripts/backup.sh backup

# 临时修改数据目录
DATA_DIR=/path/to/data ./scripts/backup.sh backup
```

## 版本历史

- **v1.1.0** (当前): 添加恢复功能，精简代码，改进日志格式
- **v1.0.0**: 初始版本，支持多种压缩算法和自动清理

## 支持与反馈

如有问题或建议，请检查：
1. 脚本帮助：`./scripts/backup.sh help`
2. 日志文件：`logs/backup_*.log`
3. 本文档：`scripts/backup.md`

---

*最后更新：2025-12-05*
*脚本版本：v1.1.0*