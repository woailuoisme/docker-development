#!/bin/sh
set -eu

GARAGE_BIN="/garage"
READY_TIMEOUT_SEC="${GARAGE_READY_TIMEOUT_SEC:-120}"
POLL_INTERVAL_SEC="${GARAGE_POLL_INTERVAL_SEC:-1}"

# 输出带时间戳的日志
log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# 启动 Garage 并返回进程号
start_garage() {
  "$GARAGE_BIN" server &
  garage_pid=$!
  echo "$garage_pid"
}

# 等待 Garage 就绪，超时返回失败
wait_for_ready() {
  end_time=$(( $(date +%s) + READY_TIMEOUT_SEC ))
  while :; do
    if "$GARAGE_BIN" status >/dev/null 2>&1; then
      return 0
    fi
    if [ "$(date +%s)" -ge "$end_time" ]; then
      return 1
    fi
    sleep "$POLL_INTERVAL_SEC"
  done
}

# 获取布局输出（允许失败）
get_layout_output() {
  "$GARAGE_BIN" layout show 2>&1 || true
}

# 解析布局版本号
get_layout_version() {
  echo "$1" | awk -F': ' '/Current cluster layout version/ {print $2}'
}

# 判断是否需要初始化布局
needs_init() {
  layout_output="$1"
  if echo "$layout_output" | grep -qi "Layout not ready"; then
    return 0
  fi
  layout_version="$(get_layout_version "$layout_output")"
  if [ -n "$layout_version" ] && [ "$layout_version" -ge 1 ]; then
    return 1
  fi
  return 0
}

# 应用单节点布局
apply_layout() {
  node_id="$("$GARAGE_BIN" node id | awk -F'@' '{print $1}')"
  zone="${GARAGE_INIT_ZONE:-dc1}"
  capacity="${GARAGE_INIT_CAPACITY:-10G}"
  "$GARAGE_BIN" layout assign -z "$zone" -c "$capacity" "$node_id"
  "$GARAGE_BIN" layout apply --version 1
}

# 脚本入口
main() {
  garage_pid="$(start_garage)"
  # shellcheck disable=SC2064
  trap "kill $garage_pid" INT TERM

  if ! wait_for_ready; then
    log "Garage ready check timed out"
    exit 1
  fi

  layout_output="$(get_layout_output)"
  if needs_init "$layout_output"; then
    apply_layout
  fi

  wait "$garage_pid"
}

main
