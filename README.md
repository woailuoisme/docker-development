# Lunchbox - Docker 镜像集合

一套精心构建的 Docker 镜像集合，专注于 PHP 应用开发和部署。

## 🚀 特性

- **多架构支持**: 支持 amd64 和 arm64 架构
- **PHP 全栈**: 包含 CLI、FPM、Octane 等多种 PHP 运行环境
- **现代化工具**: 集成 RoadRunner、Swoole、FrankenPHP 等高性能服务器
- **多仓库同步**: 自动同步到 Docker Hub、RedHat Registry、腾讯云 TCR

## 📦 主要镜像

### PHP 基础镜像
- `php-base-cli` - PHP CLI 基础环境
- `php-base-fpm` - PHP FPM 基础环境  
- `php-base-octane` - Laravel Octane 支持 (RoadRunner + Swoole + FrankenPHP)
- `php-base-simple-cli` - 精简版 CLI 环境

### 应用镜像
- `php-fpm` - 应用 FPM 环境
- `php-franken` - FrankenPHP 应用环境
- `php-horizon` - Laravel Horizon 队列处理
- `php-worker` - 后台工作进程
- `php-schedule` - 定时任务调度

### 服务镜像
- `caddy-base` - Caddy Web 服务器
- `nginx` - Nginx Web 服务器
- `pgsql` - PostgreSQL 数据库
- `redis` - Redis 缓存
- `rabbitmq` - RabbitMQ 消息队列

## 🛠️ 使用方式

### 构建镜像
```bash
# 手动触发构建工作流
# 通过 GitHub Actions 界面选择要构建的镜像
```

### 拉取镜像
```bash
# Docker Hub
docker pull jiaoio/php-base-cli:latest

# 腾讯云 TCR  
docker pull ccr.ccs.tencentyun.com/jiaoio/php-base-cli:latest

# RedHat Registry
docker pull quay.io/jiaoio/php-base-cli:latest
```

## 🔧 开发

### 项目结构
```
lunchbox/
├── .github/workflows/    # CI/CD 工作流
├── php-base-*/          # PHP 基础镜像
├── php-*/              # PHP 应用镜像
├── caddy-base/         # Caddy 镜像
└── nginx/              # Nginx 镜像
```

### 构建参数
- `CHANGE_SOURCE` - 是否使用国内镜像源
- `TIMEZONE` - 时区设置 (默认: Asia/Shanghai)
- `WITH_*` - 可选功能开关

## 📋 自动化

### 镜像构建
- 手动触发多架构构建
- 自动推送到多个镜像仓库

### 镜像同步
- 定时同步所有镜像到腾讯云 TCR
- 支持所有标签和架构版本

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**为现代 PHP 应用提供可靠的容器化解决方案**