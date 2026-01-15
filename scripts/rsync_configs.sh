#!/bin/bash

# rsync 同步脚本 - 同步 SSL 证书配置文件到远程服务器
# 用途: 同步 aliyun.ini 和 cloudflare.ini 到服务器的 /var/docker/lunchbox/certbot/conf 目录
#       同步 ssh 文件夹到服务器的 /var/docker/lunchbox/ssh 目录
# 注意: 使用 -a 参数会保留文件权限、时间戳、所有者和组信息

# 配置变量
REMOTE_USER=$(grep -E "^REMOTE_USER=" ../.env 2>/dev/null | cut -d'=' -f2 | tr -d '\r\n' || echo "root")                    # 远程服务器用户名（从 .env 文件获取或使用默认值）
REMOTE_HOST=$(grep -E "^REMOTE_HOST=" ../.env 2>/dev/null | cut -d'=' -f2 | tr -d '\r\n' || echo "8.155.171.54")            # 远程服务器地址（从 .env 文件获取或使用默认值）
REMOTE_PATH=$(grep -E "^DOCKER_PATH=" ../.env 2>/dev/null | cut -d'=' -f2 | tr -d '\r\n' || echo "/var/docker/lunchbox")    # 远程服务器目标路径（从 .env 文件获取或使用默认值）
LOCAL_PATH="./"                       # 本地文件路径

# 要同步的文件列表
#FILES_TO_SYNC=("aliyun.ini" "cloudflare.ini")
FILES_TO_SYNC=("aliyun.ini")
SSH_FOLDER="ssh"

# 颜色输出函数
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

# 检查本地文件是否存在
check_local_files() {
    local missing_files=()

    for file in "${FILES_TO_SYNC[@]}"; do
        if [[ ! -f "${LOCAL_PATH}${file}" ]]; then
            missing_files+=("$file")
        fi
    done

    # 检查 SSH 文件夹是否存在
    if [[ ! -d "${LOCAL_PATH}${SSH_FOLDER}" ]]; then
        print_warning "SSH 文件夹 ${SSH_FOLDER} 不存在，将跳过 SSH 文件夹同步"
        SYNC_SSH=false
    else
        SYNC_SSH=true
    fi

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "以下文件在本地不存在: ${missing_files[*]}"
        return 1
    fi

    return 0
}

# 执行 rsync 同步
sync_files() {
    local file_count=0

    for file in "${FILES_TO_SYNC[@]}"; do
        print_info "正在同步文件: $file"

        # 使用 rsync 同步文件 (-a 参数保留权限、时间戳、所有者等信息)
        rsync -avz --progress \
            -e "ssh -o StrictHostKeyChecking=no" \
            "${LOCAL_PATH}${file}" \
            "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/certbot/conf/"

        if [[ $? -eq 0 ]]; then
            print_success "文件 $file 同步成功"
            ((file_count++))
        else
            print_error "文件 $file 同步失败"
            return 1
        fi
    done

    print_success "所有文件同步完成 ($file_count/${#FILES_TO_SYNC[@]})"

    # 同步 SSH 文件夹
    if [[ "$SYNC_SSH" == "true" ]]; then
        print_info "正在同步 SSH 文件夹: $SSH_FOLDER"

        rsync -avz --progress \
            -e "ssh -o StrictHostKeyChecking=no" \
            "${LOCAL_PATH}${SSH_FOLDER}/" \
            "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${SSH_FOLDER}/"

        if [[ $? -eq 0 ]]; then
            print_success "SSH 文件夹同步成功"
        else
            print_error "SSH 文件夹同步失败"
            return 1
        fi
    fi

    return 0
}

# 显示使用说明
show_usage() {
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -u, --user USER     指定远程用户名 (默认: $REMOTE_USER)"
    echo "  -H, --host HOST     指定远程主机地址 (默认: $REMOTE_HOST)"
    echo "  -p, --path PATH     指定远程路径 (默认: $REMOTE_PATH)"
    echo "  -l, --local PATH    指定本地路径 (默认: $LOCAL_PATH)"
    echo "  -d, --dry-run       模拟运行，不实际同步文件"
    echo ""
    echo "示例:"
    echo "  $0 -u deploy -H example.com -p /opt/lunchbox"
    echo "  $0 --dry-run"
    echo ""
    echo "权限保留说明:"
    echo "  - 使用 -a 参数会保留文件权限、时间戳、所有者和组信息"
    echo "  - SSH 密钥文件的 600 权限会被正确保留"
    echo "  - 配置文件的不同权限设置会被正确同步"
}

# 处理命令行参数
handle_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -u|--user)
                REMOTE_USER="$2"
                shift 2
                ;;
            -H|--host)
                REMOTE_HOST="$2"
                shift 2
                ;;
            -p|--path)
                REMOTE_PATH="$2"
                shift 2
                ;;
            -l|--local)
                LOCAL_PATH="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                print_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    print_info "开始 SSL 证书配置文件同步"
    print_info "远程服务器: ${REMOTE_USER}@${REMOTE_HOST}"
    print_info "目标路径: ${REMOTE_PATH}/certbot/conf"

    # 检查本地文件
    if ! check_local_files; then
        exit 1
    fi

    # 显示要同步的文件列表
    print_info "要同步的文件: ${FILES_TO_SYNC[*]}"
    if [[ "$SYNC_SSH" == "true" ]]; then
        print_info "要同步的文件夹: $SSH_FOLDER"
    fi

    # 如果是模拟运行，只显示信息
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "模拟运行模式 - 不会实际同步文件"
        print_info "将执行以下同步操作:"
        for file in "${FILES_TO_SYNC[@]}"; do
            echo "  rsync ${LOCAL_PATH}${file} -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/certbot/conf/"
        done
        if [[ "$SYNC_SSH" == "true" ]]; then
            echo "  rsync ${LOCAL_PATH}${SSH_FOLDER}/ -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${SSH_FOLDER}/"
        fi
        exit 0
    fi

    # 执行同步
    if sync_files; then
        if [[ "$SYNC_SSH" == "true" ]]; then
            print_success "所有 SSL 证书配置文件和 SSH 文件夹已成功同步到远程服务器"
        else
            print_success "所有 SSL 证书配置文件已成功同步到远程服务器"
        fi
    else
        print_error "同步过程中出现错误"
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    handle_arguments "$@"
    main
fi
