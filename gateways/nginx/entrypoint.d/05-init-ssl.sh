#!/usr/bin/env bash
set -euo pipefail

# 若未设置 SITE_ADDRESS 则跳过自签证书初始化
if [ -z "${SITE_ADDRESS:-}" ]; then
	exit 0
fi

CERT_DIR="/etc/nginx/ssl/live/${SITE_ADDRESS}"
CERT_FILE="${CERT_DIR}/fullchain.pem"
KEY_FILE="${CERT_DIR}/privkey.pem"

if [ ! -f "${CERT_FILE}" ] || [ ! -f "${KEY_FILE}" ]; then
	echo ">> [SSL Bootstrap] Certificate not found for ${SITE_ADDRESS}."
	echo ">> [SSL Bootstrap] Generating temporary self-signed wildcard certificate for *.${SITE_ADDRESS} and ${SITE_ADDRESS}..."
	mkdir -p "${CERT_DIR}"
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout "${KEY_FILE}" \
		-out "${CERT_FILE}" \
		-subj "/CN=${SITE_ADDRESS}" \
		-addext "subjectAltName=DNS:${SITE_ADDRESS},DNS:*.${SITE_ADDRESS}" 2> /dev/null \
		|| openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout "${KEY_FILE}" \
			-out "${CERT_FILE}" \
			-subj "/CN=*.${SITE_ADDRESS}" 2> /dev/null
	echo ">> [SSL Bootstrap] Temporary certificate ready at ${CERT_DIR}."
fi
