#!/usr/bin/env bash
###
# File: 41-configure-compose.sh
# Project: start
# File Created: Monday, 21st October 2024 10:19:15 pm
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Sunday, 27th October 2024 2:54:38 pm
# Modified By: Josh5 (jsunnex@gmail.com)
###

print_log info "Create custom docker-compose.yml file"

echo "  - Create /var/lib/docker/.env file."
ENV_FILE=$(
    cat <<EOF
#@ VPN Config
# Provider
VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER:?}
VPN_TYPE=${VPN_TYPE:?}
WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY:?}
WIREGUARD_MTU=${WIREGUARD_MTU:-1420}
WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL=25s
# Connection Selection
SERVER_COUNTRIES=${SERVER_COUNTRIES:-}
SERVER_REGIONS=${SERVER_REGIONS:-}
SERVER_CITIES=${SERVER_CITIES:-}
SERVER_HOSTNAMES=${SERVER_HOSTNAMES:-}
# Connection Properties
FREE_ONLY=${FREE_ONLY:-}
STREAM_ONLY=${STREAM_ONLY:-}
SECURE_CORE_ONLY=${SECURE_CORE_ONLY:-}
TOR_ONLY=${TOR_ONLY:-}
PORT_FORWARD_ONLY=${PORT_FORWARD_ONLY:-}
VPN_PORT_FORWARDING=${VPN_PORT_FORWARDING:-}
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
HLS_PROXY_HOST_IP=${HLS_PROXY_HOST_IP:?}
HLS_PROXY_PORT=${HLS_PROXY_PORT:-8080}
EOF
)
docker exec -i ${dind_continer_name:?} sh -c 'echo "'"$ENV_FILE"'" > /var/lib/docker/.env'

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
    image: ghcr.io/josh5/hls-proxy:latest
    restart: unless-stopped
    network_mode: service:gluetun
    env_file: [.env]
EOF
)
docker exec -i ${dind_continer_name:?} sh -c 'echo "'"$COMPOSE_FILE"'" > /var/lib/docker/docker-compose.yml'
