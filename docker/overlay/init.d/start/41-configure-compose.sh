#!/usr/bin/env bash
###
# File: 41-configure-compose.sh
# Project: start
# File Created: Monday, 21st October 2024 10:19:15 pm
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Tuesday, 5th November 2024 12:16:21 am
# Modified By: Josh5 (jsunnex@gmail.com)
###

print_log info "Create custom docker-compose.yml file"

echo "  - Create /var/lib/docker/.env file."
ENV_FILE=$(
    cat <<EOF
# DNS Settings
DNS_ADDRESS=${DNS_ADDRESS:-}
DOT=${DOT:-off}
BLOCK_MALICIOUS=${BLOCK_MALICIOUS:-off}
BLOCK_SURVEILLANCE=${BLOCK_SURVEILLANCE:-off}
BLOCK_ADS=${BLOCK_ADS:-off}
# Healthcheck Options
HEALTH_VPN_DURATION_INITIAL=20s
HEALTH_VPN_DURATION_ADDITION=5s
HEALTH_SUCCESS_WAIT_DURATION=30s

#@ HLS Proxy Config
HLS_PROXY_LOG_LEVEL=${HLS_PROXY_LOG_LEVEL:-1}
HLS_PROXY_HOST_IP=${HLS_PROXY_HOST_IP:-}
HLS_PROXY_PORT=${HLS_PROXY_PORT:-8080}
EOF
)
docker exec -i ${dind_continer_name:?} sh -c 'echo "'"$ENV_FILE"'" > /var/lib/docker/.env'

echo "  - Append provider-specific env vars to /var/lib/docker/.env"
EXTRA_ENV=$(
    env | while IFS='=' read -r key value; do
        case "${key}" in
        DIND_*|VPN_HEALTH_*|HLS_PROXY_*|DOCKER_*|KEEP_ALIVE|STACK_NAME|PLACEMENT_CONSTRAINT)
            continue
            ;;
        PATH|HOME|HOSTNAME|SHLVL|PWD|TERM|LANG|USER|LOGNAME|SHELL|TZ|_)
            continue
            ;;
        LC_*)
            continue
            ;;
        esac
        if [ -z "${value:-}" ]; then
            continue
        fi
        if [[ "${key}" =~ ^[A-Z0-9_]+$ ]]; then
            echo "${key}=${value}"
        fi
    done
)
if [ -n "${EXTRA_ENV:-}" ]; then
    docker exec -i ${dind_continer_name:?} sh -c 'cat >> /var/lib/docker/.env' <<< "${EXTRA_ENV}"
fi

echo "  - Create /var/lib/docker/docker-compose.yml file."
COMPOSE_FILE=$(
    cat <<EOF
services:
  gluetun:
    image: qmcgaw/gluetun:latest
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    env_file: [.env]
    ports:
      - '${HLS_PROXY_PORT}:${HLS_PROXY_PORT}'
    dns:
      - 1.1.1.1
      - 8.8.4.4

  proxy:
    image: ${HLS_PROXY_DOCKER_IMAGE:-ghcr.io/josh5/warren-bank-hls-proxy:latest}
    restart: unless-stopped
    network_mode: service:gluetun
    env_file: [.env]
EOF
)
docker exec -i ${dind_continer_name:?} sh -c 'echo "'"$COMPOSE_FILE"'" > /var/lib/docker/docker-compose.yml'
