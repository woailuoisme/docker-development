#!/bin/bash

# MinIO完整设置脚本
# 功能：自动安装mc客户端并配置MinIO存储桶

set -e

# 函数：检测操作系统和架构
detect_system() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    # 处理架构名称映射
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        i386|i686)
            ARCH="386"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            echo "❌ 不支持的架构: $ARCH"
            exit 1
            ;;
    esac

    # 检查操作系统支持
    if [[ $OS != "linux" && $OS != "darwin" ]]; then
        echo "❌ 不支持的操作系统: $OS"
        exit 1
    fi

    echo "✓ 检测到系统: $OS-$ARCH"
}

# 函数：下载并安装mc客户端
install_mc() {
    # 检查mc是否已安装
    if command -v mc &> /dev/null; then
        echo "✓ mc客户端已安装，版本:"
        mc --version
        return 0
    fi

    # 最新版mc下载地址
    BASE_URL="https://dl.min.io/client/mc/release"
    DOWNLOAD_URL="$BASE_URL/$OS-$ARCH/mc"

    # 临时下载路径
    TEMP_FILE=$(mktemp)

    echo "📥 正在下载mc客户端: $DOWNLOAD_URL"
    if ! curl -sSL "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
        echo "❌ 下载失败，请检查网络连接"
        rm -f "$TEMP_FILE"
        exit 1
    fi

    # 赋予执行权限
    chmod +x "$TEMP_FILE"

    # 移动到系统可执行目录
    if [[ -w /usr/local/bin ]]; then
        DEST="/usr/local/bin/mc"
    else
        DEST="$HOME/.local/bin/mc"
        mkdir -p "$(dirname "$DEST")"
    fi

    echo "📦 安装到: $DEST"
    mv "$TEMP_FILE" "$DEST"

    # 验证安装
    if command -v mc &> /dev/null; then
        echo "✅ mc客户端安装成功！版本:"
        mc --version
    else
        echo "❌ 安装失败，请将 $DEST 所在目录添加到PATH环境变量"
        exit 1
    fi
}

# 函数：从.env文件加载环境变量
load_env_vars() {
    if [ -f "./.env" ]; then
        # 安全地加载.env文件中的变量
        export $(grep -E '^(MINIO_ROOT_USER|MINIO_ROOT_PASSWORD|MINIO_PORT)=' ./.env | xargs)
        echo "✓ 从.env文件加载MinIO配置"
        echo "  - 用户名: $MINIO_ROOT_USER"
        echo "  - 端口: $MINIO_PORT"
    else
        echo "❌ .env文件不存在，请确保在当前目录运行此脚本"
        exit 1
    fi
}

# 函数：等待MinIO服务启动
wait_for_minio() {
    echo "⏳ 等待MinIO服务启动..."
    sleep 5
    
    # 尝试连接MinIO服务
    if ! curl -s http://localhost:${MINIO_PORT}/minio/health/live > /dev/null; then
        echo "⚠️  MinIO服务可能尚未完全启动，继续等待..."
        sleep 3
    fi
}

# 函数：设置MinIO客户端别名
setup_mc_alias() {
    echo "🔗 设置MinIO客户端别名..."
    mc alias set local http://localhost:${MINIO_PORT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
    echo "✅ MinIO别名设置完成"
}

# 函数：检查存储桶是否存在，不存在则创建，存在则更新策略
check_and_manage_bucket() {
    local bucket_name=$1
    local policy=$2
    
    echo "🪣 处理存储桶: $bucket_name"
    
    # 检查存储桶是否存在
    if mc ls local/$bucket_name >/dev/null 2>&1; then
        echo "  ✓ 存储桶已存在，更新访问策略..."
        # 存储桶存在，只更新策略
        mc anonymous set $policy local/$bucket_name
    else
        echo "  + 存储桶不存在，创建并设置策略..."
        # 存储桶不存在，创建并设置策略
        mc mb local/$bucket_name
        mc anonymous set $policy local/$bucket_name
    fi
    
    echo "  ✅ $bucket_name 存储桶处理完成"
}

# 函数：配置MinIO存储桶
configure_minio_buckets() {
    echo "🚀 开始配置MinIO存储桶..."
    
    check_and_manage_bucket "backup" "private"
    check_and_manage_bucket "asset" "public"
    check_and_manage_bucket "lunchbox" "public"

    echo "✅ 存储桶配置完成!"
    echo "📋 存储桶详情:"
    echo "  - lunchbox: 私有存储桶"
    echo "  - backup: 公开读取存储桶"

    # 列出所有存储桶确认处理成功
    echo "📊 当前所有存储桶:"
    mc ls local
}

# 主函数
main() {
    echo "🎯 MinIO完整设置脚本启动"
    echo "================================"
    
    # 步骤1: 检测系统
    detect_system
    
    # 步骤2: 安装mc客户端
    install_mc
    
    # 步骤3: 加载环境变量
    load_env_vars
    
    # 步骤4: 等待MinIO服务
    wait_for_minio
    
    # 步骤5: 设置mc别名
    setup_mc_alias
    
    # 步骤6: 配置存储桶
    configure_minio_buckets
    
    echo "================================"
    echo "🎉 MinIO设置完成!"
    echo "💡 提示: 您可以通过以下方式访问MinIO:"
    echo "  - Web界面: http://localhost:${MINIO_PORT_UI:-9527}"
    echo "  - API端点: http://localhost:${MINIO_PORT}"
}

# 执行主函数
main "$@"