-- 基础动态 WAF 示例
local ip_blacklist = ngx.shared.ip_blacklist
local client_ip = ngx.var.remote_addr

-- 1. 检查黑名单
local is_black, _ = ip_blacklist:get(client_ip)
if is_black then
    ngx.log(ngx.WARN, "Blocked IP: ", client_ip)
    return ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- 2. 简单的速率限制 (演示逻辑)
-- 实际生产中建议使用 lua-resty-limit-traffic 库
local limit_req_store = ngx.shared.limit_req_store
local key = "rate_limit_" .. client_ip
local req_count, _ = limit_req_store:get(key)

if not req_count then
    limit_req_store:set(key, 1, 1) -- 1秒内有效
else
    if req_count > 100 then -- 每秒超过 100 次请求
        ip_blacklist:set(client_ip, true, 3600) -- 拉黑 1 小时
        ngx.log(ngx.ERR, "IP ", client_ip, " exceeded rate limit, blacklisting...")
        return ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    limit_req_store:incr(key, 1)
end
