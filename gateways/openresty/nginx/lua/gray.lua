-- 基础灰度发布示例
-- 根据 Cookie 中的 user_id 决定转发后端

local user_id = ngx.var.cookie_user_id
local target_upstream = "backend_stable" -- 默认版本

if user_id then
    -- 取模运算: 尾号为 0-9 的用户进入灰度环境 (10% 流量)
    local id_num = tonumber(user_id)
    if id_num and id_num % 100 < 10 then
        target_upstream = "backend_canary"
        ngx.log(ngx.INFO, "User ", user_id, " routed to CANARY")
    end
end

-- 将结果存入变量，供后续 proxy_pass 使用
ngx.var.ups_target = target_upstream
