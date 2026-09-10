#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Aqua Security Trivy 统一安全扫描辅助脚本
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 读取环境变量或设置默认值
CACHE_DIR="${DATA_PATH:-${ROOT_DIR}/data/}trivy/cache"
REPORTS_DIR="${DATA_PATH:-${ROOT_DIR}/data/}trivy/reports"
TRIVY_IMAGE="aquasec/trivy:latest"

mkdir -p "${CACHE_DIR}" "${REPORTS_DIR}"

print_usage() {
	cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  image <image_name>       扫描指定 Docker 镜像的 CVE 漏洞与软件包依赖
  fs <path>                扫描指定本地目录或代码仓库的文件系统与依赖组件
  config <path>            扫描 Dockerfile、Compose 或 K8s 配置文件的 IaC 风险
  sbom <image_name> [file] 生成指定镜像的 SBOM 软件物料清单 (CycloneDX 格式)
  server-status            检测常驻 Trivy Server 服务端健康状态
  clean                    清理本地持久化的漏洞数据库与缓存数据
  help                     显示此帮助信息

Examples:
  $(basename "$0") image alpine:latest
  $(basename "$0") fs /path/to/app
  $(basename "$0") config .
  $(basename "$0") sbom nginx:alpine ./reports/nginx-sbom.json
EOF
}

# 基础执行包装函数 (免安装 Trivy，统一挂载缓存与 Docker 套接字)
run_trivy() {
	docker run --rm -i \
		-v "${CACHE_DIR}:/root/.cache/trivy" \
		-v "/var/run/docker.sock:/var/run/docker.sock:ro" \
		-v "${ROOT_DIR}:/workspace/project:ro" \
		-v "${SCRIPT_DIR}/trivy.yaml:/root/trivy.yaml:ro" \
		-v "${SCRIPT_DIR}/.trivyignore:/root/.trivyignore:ro" \
		-v "${REPORTS_DIR}:/root/reports" \
		-w /workspace/project \
		"${TRIVY_IMAGE}" "$@"
}

cmd="${1:-help}"
shift || true

case "${cmd}" in
	image)
		if [ "$#" -lt 1 ]; then
			echo "错误: 请指定要扫描的镜像名称，例如: $(basename "$0") image alpine:latest"
			exit 1
		fi
		image_name="$1"
		shift
		echo "→ 正在扫描镜像安全漏洞: ${image_name}..."
		run_trivy image "${image_name}" "$@"
		;;

	fs)
		target_path="${1:-.}"
		shift || true
		abs_target="$(cd "${target_path}" 2> /dev/null && pwd || echo "${target_path}")"
		echo "→ 正在扫描文件系统与代码依赖: ${abs_target}..."
		docker run --rm -i \
			-v "${CACHE_DIR}:/root/.cache/trivy" \
			-v "${abs_target}:/scan-target:ro" \
			-v "${SCRIPT_DIR}/trivy.yaml:/root/trivy.yaml:ro" \
			-v "${SCRIPT_DIR}/.trivyignore:/root/.trivyignore:ro" \
			-w /scan-target \
			"${TRIVY_IMAGE}" fs /scan-target "$@"
		;;

	config | iac)
		target_path="${1:-.}"
		shift || true
		abs_target="$(cd "${target_path}" 2> /dev/null && pwd || echo "${target_path}")"
		echo "→ 正在审计 IaC 配置文件安全风险: ${abs_target}..."
		docker run --rm -i \
			-v "${CACHE_DIR}:/root/.cache/trivy" \
			-v "${abs_target}:/scan-target:ro" \
			-v "${SCRIPT_DIR}/trivy.yaml:/root/trivy.yaml:ro" \
			-v "${SCRIPT_DIR}/.trivyignore:/root/.trivyignore:ro" \
			-w /scan-target \
			"${TRIVY_IMAGE}" config /scan-target "$@"
		;;

	sbom)
		if [ "$#" -lt 1 ]; then
			echo "错误: 请指定镜像名称，例如: $(basename "$0") sbom alpine:latest [output.json]"
			exit 1
		fi
		image_name="$1"
		out_file="${2:-}"
		if [ -n "${out_file}" ]; then
			echo "→ 正在生成镜像 ${image_name} 的 SBOM 到 ${out_file}..."
			run_trivy image --format cyclonedx "${image_name}" > "${out_file}"
			echo "✔ SBOM 已成功保存至: ${out_file}"
		else
			echo "→ 正在生成镜像 ${image_name} 的 SBOM..."
			run_trivy image --format cyclonedx "${image_name}"
		fi
		;;

	server-status)
		server_port="${TRIVY_PORT:-4954}"
		echo "→ 检查 Trivy Server (127.0.0.1:${server_port}/healthz)..."
		if curl -sf "http://127.0.0.1:${server_port}/healthz" > /dev/null 2>&1; then
			echo "✔ Trivy Server 运行正常 (Healthy)"
		else
			echo "✖ 无法连接到 Trivy Server (127.0.0.1:${server_port})。请确认是否已执行 'docker compose up -d trivy'。"
			exit 1
		fi
		;;

	clean)
		echo "→ 正在清理 Trivy 漏洞库与元数据缓存 (${CACHE_DIR})..."
		run_trivy clean --all
		echo "✔ Trivy 缓存清理完成"
		;;

	help | --help | -h)
		print_usage
		;;

	*)
		echo "未知指令: ${cmd}"
		print_usage
		exit 1
		;;
esac
