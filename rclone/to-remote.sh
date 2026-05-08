#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -lt 4 ]; then
  cat >&2 <<'EOF'
Usage:
  to-remote.sh <copy|sync|cp|sy> <ali-oss|ali|r2|cloudflare-r2> <source> <bucket>

Examples:
  to-remote.sh copy ali-oss garage:default default
  to-remote.sh sync r2 garage:default default
EOF
  exit 1
fi

operation="$1"
target="$2"
source_path="$3"
bucket_name="$4"

case "${operation}" in
  copy|sync|cp|sy)
    ;;
  *)
    echo "Unknown operation: ${operation}" >&2
    exit 1
    ;;
esac

case "${target}" in
  ali-oss|ali)
    remote="ali-oss"
    ;;
  cloudflare-r2|r2)
    remote="cloudflare-r2"
    ;;
  *)
    echo "Unknown target: ${target}" >&2
    exit 1
    ;;
esac

case "${operation}" in
  cp)
    operation="copy"
    ;;
  sy)
    operation="sync"
    ;;
esac

exec bash "${script_dir}/rclone.sh" "${operation}" "${source_path}" "${remote}:${bucket_name}"
