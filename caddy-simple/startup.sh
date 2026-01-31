#!/bin/sh

# Caddy 启动脚本
# 自动格式化所有 Caddy 配置文件并启动服务

set -e

# 颜色定义
C_R="\033[31m" C_G="\033[32m" C_Y="\033[33m" C_B="\033[34m" C_C="\033[36m" C_1="\033[1m" C_0="\033[0m"

# 日志函数
log_info()    { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_B}[INFO]${C_0} %s\n" "$1"; }
log_success() { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_G}[SUCCESS]${C_0} %s\n" "$1"; }
log_warning() { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_Y}[WARNING]${C_0} %s\n" "$1"; }
log_error()   { printf "${C_C}[$(date '+%Y-%m-%d %H:%M:%S %z')]${C_0} ${C_R}[ERROR]${C_0} %s\n" "$1"; }

# 格式化 Caddy 配置文件
format_caddy_configs() {
    log_info "开始格式化 Caddy 配置文件..."

    config_files="
        /etc/caddy/Caddyfile
        $(find /etc/caddy/snippets -name "*.conf" 2>/dev/null || true)
        $(find /etc/caddy/templates -name "*.conf" 2>/dev/null || true)
    "

    formatted_count=0
    error_count=0

    for config_file in $config_files; do
        if [ -f "$config_file" ]; then
            log_info "格式化文件: $config_file"
            if caddy fmt --overwrite "$config_file" 2>/dev/null; then
                log_success "成功格式化: $config_file"
                formatted_count=$((formatted_count + 1))
            else
                log_warning "格式化失败或文件已是最新: $config_file"
                error_count=$((error_count + 1))
            fi
        else
            log_warning "配置文件不存在: $config_file"
        fi
    done

    log_success "格式化完成: 成功 $formatted_count 个文件, 失败/跳过 $error_count 个文件"
}

# 验证 Caddy 配置
validate_caddy_config() {
    log_info "验证 Caddy 配置..."

    if caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
        log_success "Caddy 配置验证通过"
        return 0
    else
        log_error "Caddy 配置验证失败"
        return 1
    fi
}

# 显示 Caddy 模块信息
show_caddy_modules() {
    printf "${C_1}${C_C}=== 已安装的 Caddy 模块 ===${C_0}\n"
    caddy list-modules | grep -E "(Standard modules|Non-standard modules|Unknown modules)" || true
    printf "${C_1}${C_C}================================${C_0}\n"
}

# 显示启动配置
show_startup_config() {
    printf "${C_1}${C_C}=== Caddy 启动配置 ===${C_0}\n"
    log_info "配置文件: ${C_1}/etc/caddy/Caddyfile${C_0}"
    log_info "适配器: ${C_1}caddyfile${C_0}"
    log_info "工作目录: ${C_1}$(pwd)${C_0}"
    log_info "用户: ${C_1}$(whoami)${C_0}"
    printf "${C_1}${C_C}================================${C_0}\n"
}

# 主函数
main() {
    log_info "启动 Caddy 服务..."

    # 显示启动配置
    show_startup_config

    # 格式化配置文件
    format_caddy_configs

    # 验证配置
    if ! validate_caddy_config; then
        log_error "配置验证失败，退出启动"
        exit 1
    fi

    # 显示模块信息
    show_caddy_modules

    log_success "Caddy 服务启动准备完成"
    printf "${C_1}${C_G}启动命令: caddy run --config /etc/caddy/Caddyfile --adapter caddyfile${C_0}\n"
    printf "\n"

    # 启动 Caddy
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止 Caddy..."; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
