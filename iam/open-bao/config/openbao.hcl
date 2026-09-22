ui = true

# OpenBao 已移除 mlock 支持：写 disable_mlock 会导致启动直接失败，
# 官方替代做法是关闭或加密宿主机 Swap，见 https://openbao.org/docs/install/#post-installation-hardening

storage "raft" {
  path    = "/openbao/file"
  node_id = "openbao-node-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1 # 容器间走内网明文，外部 HTTPS 由 Caddy 网关统一卸载
}

# raft 存储强制要求 cluster_addr，缺失会启动失败
api_addr     = "http://open-bao:8200"
cluster_addr = "http://open-bao:8201"

default_lease_ttl = "168h" # 7 天
max_lease_ttl     = "720h" # 30 天

# v2.3.2 起禁止经 API/CLI 启用审计设备，只能在配置中声明；
# 该块在活跃节点重启或收到 SIGHUP 时生效
audit "file" "to-file" {
  description = "审计日志写入持久化目录"
  options {
    file_path = "/openbao/logs/audit.log"
  }
}
