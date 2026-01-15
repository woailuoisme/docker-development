#!/bin/bash

# ============================================
# Lunchbox 数据备份恢复脚本
# 备份 data 文件夹到 backup 文件夹
# 支持从备份恢复数据
# ============================================

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本信息
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.1.0"

# 默认配置
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="$PROJECT_ROOT/data"
BACKUP_DIR="$PROJECT_ROOT/backup"
LOG_DIR="$PROJECT_ROOT/logs"
MAX_BACKUPS=30  # 保留的最大备份数量
COMPRESS=true   # 是否压缩备份
COMPRESS_TYPE="gzip"  # 压缩算法: gzip, bzip2, xz

# 日志函数
log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1" >&2
}

# 显示帮助信息
show_help() {
    cat << EOF
Lunchbox 数据备份恢复脚本 v${SCRIPT_VERSION}

用法: $SCRIPT_NAME <命令> [选项]

命令:
  backup    创建数据备份
  restore   从备份恢复数据
  list      列出可用备份
  help      显示此帮助信息

备份选项:
  -t, --type TYPE     压缩算法: gzip, bzip2, xz (默认: $COMPRESS_TYPE)
  -c, --no-compress   不压缩备份文件
  -m, --max N         保留的最大备份数量 (默认: $MAX_BACKUPS)

恢复选项:
  -f, --file FILE     指定备份文件 (默认: 最新备份)
  -y, --yes           自动确认恢复操作

示例:
  $SCRIPT_NAME backup              # 创建备份
  $SCRIPT_NAME backup -t xz        # 使用xz压缩创建备份
  $SCRIPT_NAME list                # 列出备份文件
  $SCRIPT_NAME restore             # 从最新备份恢复
  $SCRIPT_NAME restore -f backup_20251205_102037.tar.xz  # 从指定备份恢复
  $SCRIPT_NAME help                # 显示帮助

压缩算法:
  gzip:   速度快，压缩率中等 (默认)
  bzip2:  速度中等，压缩率较好
  xz:     速度慢，压缩率最高
EOF
}

# 检查必需工具
check_requirements() {
    local missing_tools=()

    if ! command -v tar &> /dev/null; then
        missing_tools+=("tar")
    fi

    if [ "$COMPRESS" = true ]; then
        case "$COMPRESS_TYPE" in
            "gzip")
                if ! command -v gzip &> /dev/null; then
                    missing_tools+=("gzip")
                fi
                ;;
            "bzip2")
                if ! command -v bzip2 &> /dev/null; then
                    missing_tools+=("bzip2")
                fi
                ;;
            "xz")
                if ! command -v xz &> /dev/null; then
                    missing_tools+=("xz")
                fi
                ;;
        esac
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "缺少必需工具: ${missing_tools[*]}"
        return 1
    fi

    return 0
}

# 检查目录
check_directories() {
    # 检查并创建数据目录
    if [ ! -d "$DATA_DIR" ]; then
        log_warning "数据目录不存在: $DATA_DIR"
        log_info "创建数据目录..."
        mkdir -p "$DATA_DIR" || {
            log_error "无法创建数据目录"
            return 1
        }
        log_success "数据目录创建成功"
    fi

    # 创建备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "创建备份目录: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR" || {
            log_error "无法创建备份目录"
            return 1
        }
    fi

    # 创建日志目录
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            log_warning "无法创建日志目录，使用当前目录"
            LOG_DIR="."
        }
    fi

    return 0
}

# 生成备份文件名
generate_backup_filename() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')

    if [ "$COMPRESS" = true ]; then
        case "$COMPRESS_TYPE" in
            "gzip") echo "backup_${timestamp}.tar.gz" ;;
            "bzip2") echo "backup_${timestamp}.tar.bz2" ;;
            "xz") echo "backup_${timestamp}.tar.xz" ;;
            *) echo "backup_${timestamp}.tar.gz" ;;
        esac
    else
        echo "backup_${timestamp}.tar"
    fi
}

# 创建备份
create_backup() {
    local backup_file="$BACKUP_DIR/$(generate_backup_filename)"
    local log_file="$LOG_DIR/backup_$(date '+%Y%m%d').log"

    log_info "开始备份数据..."
    log_info "源目录: $DATA_DIR"
    log_info "目标文件: $(basename "$backup_file")"

    # 构建tar命令
    local tar_cmd="tar"
    local tar_opts="cf"

    if [ "$COMPRESS" = true ]; then
        case "$COMPRESS_TYPE" in
            "gzip") tar_opts="czf" ;;
            "bzip2") tar_opts="cjf" ;;
            "xz") tar_opts="cJf" ;;
        esac
        log_info "使用压缩: $COMPRESS_TYPE"
    fi

    # 执行备份
    log_info "正在创建备份文件..."
    local start_time=$(date +%s)

    if ! $tar_cmd $tar_opts "$backup_file" -C "$PROJECT_ROOT" data/ >> "$log_file" 2>&1; then
        log_error "备份失败"
        rm -f "$backup_file" 2>/dev/null
        return 1
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # 计算备份大小
    local backup_size=$(du -h "$backup_file" 2>/dev/null | cut -f1)

    log_success "备份完成"
    log_info "备份大小: $backup_size"
    log_info "耗时: ${duration}秒"
    log_info "日志文件: $log_file"

    # 清理旧备份
    cleanup_old_backups

    return 0
}

# 清理旧备份
cleanup_old_backups() {
    local backup_pattern="backup_*.tar*"
    local backup_files=($(find "$BACKUP_DIR" -maxdepth 1 -name "$backup_pattern" -type f 2>/dev/null | sort))
    local total_backups=${#backup_files[@]}

    if [ $total_backups -le $MAX_BACKUPS ]; then
        return 0
    fi

    local files_to_delete=$((total_backups - MAX_BACKUPS))
    log_info "清理 $files_to_delete 个旧备份..."

    for ((i=0; i<files_to_delete; i++)); do
        local file_to_delete="${backup_files[$i]}"
        log_info "删除: $(basename "$file_to_delete")"
        rm -f "$file_to_delete"
    done

    log_info "备份清理完成"
    return 0
}

# 列出备份文件
list_backups() {
    local backup_pattern="backup_*.tar*"
    local backup_files=($(find "$BACKUP_DIR" -maxdepth 1 -name "$backup_pattern" -type f 2>/dev/null | sort -r))
    local total_backups=${#backup_files[@]}

    if [ $total_backups -eq 0 ]; then
        log_info "暂无备份文件"
        return 0
    fi

    log_info "可用备份文件 ($total_backups 个):"
    echo "========================================"
    printf "%-35s %-10s %-20s\n" "文件名" "大小" "修改时间"
    echo "----------------------------------------"

    for file in "${backup_files[@]}"; do
        local filename=$(basename "$file")
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        local mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || date -r "$file" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知")
        printf "%-35s %-10s %-20s\n" "$filename" "$size" "$mtime"
    done

    echo "========================================"
    return 0
}

# 从备份恢复
restore_backup() {
    local backup_file="$1"
    local auto_confirm="$2"

    # 如果没有指定备份文件，使用最新的
    if [ -z "$backup_file" ]; then
        local backup_pattern="backup_*.tar*"
        local backup_files=($(find "$BACKUP_DIR" -maxdepth 1 -name "$backup_pattern" -type f 2>/dev/null | sort -r))

        if [ ${#backup_files[@]} -eq 0 ]; then
            log_error "没有找到备份文件"
            return 1
        fi

        backup_file="${backup_files[0]}"
    fi

    # 检查备份文件是否存在
    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在: $backup_file"
        return 1
    fi

    local backup_filename=$(basename "$backup_file")
    local backup_size=$(du -h "$backup_file" 2>/dev/null | cut -f1)

    log_info "准备恢复备份..."
    log_info "备份文件: $backup_filename"
    log_info "备份大小: $backup_size"
    log_info "目标目录: $DATA_DIR"

    # 警告：恢复会覆盖现有数据
    if [ "$auto_confirm" != "yes" ]; then
        echo "========================================"
        echo "警告：此操作将覆盖 $DATA_DIR 中的所有数据！"
        echo "备份文件: $backup_filename"
        echo "========================================"
        read -p "确认恢复？(y/N): " confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "恢复操作已取消"
            return 0
        fi
    fi

    # 检查目标目录是否为空（安全提示）
    if [ -d "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        log_warning "目标目录 $DATA_DIR 不为空，现有文件将被覆盖"
    fi

    # 执行恢复
    log_info "正在恢复数据..."
    local start_time=$(date +%s)

    # 确定压缩类型并构建解压命令
    local tar_cmd="tar"
    local tar_opts="xf"

    if [[ "$backup_filename" == *.tar.gz ]] || [[ "$backup_filename" == *.tgz ]]; then
        tar_opts="xzf"
    elif [[ "$backup_filename" == *.tar.bz2 ]] || [[ "$backup_filename" == *.tbz2 ]]; then
        tar_opts="xjf"
    elif [[ "$backup_filename" == *.tar.xz ]] || [[ "$backup_filename" == *.txz ]]; then
        tar_opts="xJf"
    fi

    # 创建临时目录用于恢复
    local temp_dir=$(mktemp -d)

    # 解压到临时目录
    if ! $tar_cmd $tar_opts "$backup_file" -C "$temp_dir"; then
        log_error "解压备份文件失败"
        rm -rf "$temp_dir"
        return 1
    fi

    # 备份现有数据（如果存在）
    if [ -d "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        local backup_before_restore="$BACKUP_DIR/before_restore_$(date '+%Y%m%d_%H%M%S').tar.gz"
        log_info "备份现有数据到: $(basename "$backup_before_restore")"
        tar czf "$backup_before_restore" -C "$PROJECT_ROOT" data/ 2>/dev/null || true
    fi

    # 清空目标目录
    rm -rf "$DATA_DIR" 2>/dev/null
    mkdir -p "$DATA_DIR"

    # 移动恢复的数据
    if [ -d "$temp_dir/data" ]; then
        mv "$temp_dir/data"/* "$DATA_DIR"/ 2>/dev/null
    else
        mv "$temp_dir"/* "$DATA_DIR"/ 2>/dev/null
    fi

    # 清理临时目录
    rm -rf "$temp_dir"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "数据恢复完成"
    log_info "耗时: ${duration}秒"
    log_info "恢复自: $backup_filename"

    return 0
}

# 主函数
main() {
    local command="$1"
    
    # 检查是否提供了命令
    if [ -z "$command" ]; then
        show_help
        exit 0
    fi
    
    shift

    # 解析命令特定的选项
    case "$command" in
        backup)
            # 解析备份选项
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -t|--type)
                        COMPRESS_TYPE="$2"
                        shift 2
                        ;;
                    -c|--no-compress)
                        COMPRESS=false
                        shift
                        ;;
                    -m|--max)
                        MAX_BACKUPS="$2"
                        shift 2
                        ;;
                    *)
                        log_error "未知选项: $1"
                        show_help
                        exit 1
                        ;;
                esac
            done
            
            # 检查环境和目录
            if ! check_requirements || ! check_directories; then
                exit 1
            fi
            
            create_backup
            ;;
            
        restore)
            local restore_file=""
            local auto_confirm="no"

            # 解析恢复选项
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -f|--file)
                        restore_file="$2"
                        shift 2
                        ;;
                    -y|--yes)
                        auto_confirm="yes"
                        shift
                        ;;
                    *)
                        log_error "未知选项: $1"
                        show_help
                        exit 1
                        ;;
                esac
            done
            
            # 检查环境和目录
            if ! check_requirements || ! check_directories; then
                exit 1
            fi

            restore_backup "$restore_file" "$auto_confirm"
            ;;
            
        list)
            # list 命令不接受额外参数
            if [[ $# -gt 0 ]]; then
                log_warning "list 命令不接受额外参数，忽略: $*"
            fi
            
            # 检查目录
            if ! check_directories; then
                exit 1
            fi
            
            list_backups
            ;;
            
        help)
            show_help
            ;;
            
        *)
            log_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 捕获中断信号
trap 'log_error "操作被用户中断"; exit 130' INT TERM

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
