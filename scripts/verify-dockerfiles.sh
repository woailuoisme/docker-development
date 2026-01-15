#!/bin/bash

# verify-dockerfiles.sh
# Dockerfile 验证脚本
# 作用：在运行 GitHub 工作流之前验证所有必需的 Dockerfile 文件是否存在

set -e

echo "🔍 验证 Lunchbox 服务的 Dockerfile"
echo "===================================="
echo ""

# 需要验证的服务列表
SERVICES=(
    "certbot"    # SSL 证书管理
    "nginx"      # Web 服务器
    "php-fpm"    # PHP 处理
    "postgres"   # 数据库
    "pgbouncer"  # 数据库连接池
    "redis"      # 缓存
    "rabbitmq"   # 消息队列
    "portainer"  # 容器管理
    "minio"      # 对象存储
)

ALL_VALID=true

# 遍历所有服务，检查 Dockerfile 是否存在
for service in "${SERVICES[@]}"; do
    dockerfile_path="./$service/Dockerfile"

    if [ -f "$dockerfile_path" ]; then
        echo "✅ $service: Dockerfile 存在于 $dockerfile_path"
    else
        echo "❌ $service: Dockerfile 不存在于 $dockerfile_path"
        ALL_VALID=false
    fi
done

echo ""
if [ "$ALL_VALID" = true ]; then
    echo "🎉 所有 Dockerfile 都存在，准备就绪可以运行 GitHub 工作流！"
    echo "   您现在可以推送代码来触发构建过程。"
else
    echo "⚠️  部分 Dockerfile 缺失。请检查上面的路径。"
    echo "   如果 Dockerfile 缺失，GitHub 工作流将会失败。"
    exit 1
fi

echo ""
echo "📋 服务上下文参考："
for service in "${SERVICES[@]}"; do
    echo "   - $service: ./$service"
done
