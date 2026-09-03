#!/bin/sh

# 自动执行 Superuser 更新/创建并打印状态
echo "Setting up PocketBase superuser: $PB_ADMIN_EMAIL..."
/pb/pocketbase superuser upsert "$PB_ADMIN_EMAIL" "$PB_ADMIN_PASSWORD"
echo "Superuser setup complete."
