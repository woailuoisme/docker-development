# 只读档应用策略：取 app-ro 的动态数据库凭据，并管理这些租约
# 令牌自查/自续期由内置 default 策略提供，无需在此重复声明
path "database/creds/app-ro" {
  capabilities = ["read"]
}

path "sys/leases/renew" {
  capabilities = ["update"]
}

path "sys/leases/revoke" {
  capabilities = ["update"]
}
