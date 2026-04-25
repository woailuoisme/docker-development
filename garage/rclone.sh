#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="${script_dir}/docker-compose.rclone.yml"

if [ "$#" -lt 2 ]; then
  cat >&2 <<'EOF'
Usage:
  rclone.sh ls <remote:path>
  rclone.sh copy <source> <destination>
  rclone.sh sync <source> <destination>
  rclone.sh delete <remote:path>
EOF
  exit 1
fi

subcommand="$1"
shift

case "${subcommand}" in
  ls|delete)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $(basename "$0") ${subcommand} <remote:path>" >&2
      exit 1
    fi
    exec docker compose -f "${compose_file}" run --rm \
      rclone --config /config/rclone.conf "${subcommand}" "$@"
    ;;
  copy|sync)
    if [ "$#" -lt 2 ]; then
      echo "Usage: $(basename "$0") ${subcommand} <source> <destination>" >&2
      exit 1
    fi
    exec docker compose -f "${compose_file}" run --rm \
      -v "${PWD}:/work" \
      -w /work \
      rclone --config /config/rclone.conf "${subcommand}" "$@"
    ;;
  *)
    echo "Unknown subcommand: ${subcommand}" >&2
    exit 1
    ;;
esac
