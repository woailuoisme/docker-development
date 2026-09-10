# ==============================================================================
# OpenBao (Linux Foundation 开源凭据与敏感数据治理引擎) 核心配置文件
# ==============================================================================

# 开启可视化 Web UI 控制台 (访问 /ui)
ui = true

# 配合 Docker cap_add: [IPC_LOCK] 锁定内存，杜绝内存敏感数据换出到磁盘 Swap
disable_mlock = false

# Raft 集成存储引擎 (官方推荐，完全替代已被废弃的 file 存储引擎)
storage "raft" {
  path    = "/openbao/file"
  node_id = "openbao-node-1"
}

# TCP 服务监听器配置
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1 # 容器间内网使用明文通信，外部 HTTPS/TLS 由 Caddy 网关统一接管卸载
}

# 服务定位与集群内部通信地址
api_addr     = "http://open-bao:8200"
cluster_addr = "http://open-bao:8201"

# 密钥与 Token 租赁生命周期默认参数
default_lease_ttl = "168h" # 7 天
max_lease_ttl     = "720h" # 30 天
