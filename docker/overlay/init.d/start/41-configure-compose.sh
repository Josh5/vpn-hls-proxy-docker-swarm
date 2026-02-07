#!/usr/bin/env bash
###
# File: 41-configure-compose.sh
# Project: start
# File Created: Monday, 21st October 2024 10:19:15 pm
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Saturday, 7th February 2026 2:29:53 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

print_log info "Create custom docker-compose.yml file"

echo "  - Create /var/lib/docker/gluetun.env file."
GLUETUN_ENV_FILE=$(
    cat <<EOF
#@ VPN Config
# Provider
VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER:?}
VPN_TYPE=${VPN_TYPE:?}
OPENVPN_USER=${OPENVPN_USER:-}
OPENVPN_PASSWORD=${OPENVPN_PASSWORD:-}
OPENVPN_ENDPOINT_PORT=${OPENVPN_ENDPOINT_PORT:-}
OPENVPN_CUSTOM_CONFIG=${OPENVPN_CUSTOM_CONFIG:-}
OPENVPN_KEY_PASSPHRASE=${OPENVPN_KEY_PASSPHRASE:-}
WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY:-}
WIREGUARD_PRESHARED_KEY=${WIREGUARD_PRESHARED_KEY:-}
WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES:-}
WIREGUARD_ENDPOINT_IP=${WIREGUARD_ENDPOINT_IP:-}
WIREGUARD_ENDPOINT_PORT=${WIREGUARD_ENDPOINT_PORT:-}
WIREGUARD_PUBLIC_KEY=${WIREGUARD_PUBLIC_KEY:-}
WIREGUARD_MTU=${WIREGUARD_MTU:-1420}
WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL=${WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL:-}
# Connection Selection
SERVER_COUNTRIES=${SERVER_COUNTRIES:-}
SERVER_REGIONS=${SERVER_REGIONS:-}
SERVER_CITIES=${SERVER_CITIES:-}
SERVER_HOSTNAMES=${SERVER_HOSTNAMES:-}
SERVER_CATEGORIES=${SERVER_CATEGORIES:-}
SERVER_NAMES=${SERVER_NAMES:-}
FIREWALL_VPN_INPUT_PORTS=${FIREWALL_VPN_INPUT_PORTS:-}
ISP=${ISP:-}
OWNED_ONLY=${OWNED_ONLY:-}
PREMIUM_ONLY=${PREMIUM_ONLY:-}
PRIVATE_INTERNET_ACCESS_OPENVPN_ENCRYPTION_PRESET=${PRIVATE_INTERNET_ACCESS_OPENVPN_ENCRYPTION_PRESET:-}
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
EOF
)
docker exec -i ${dind_continer_name:?} sh -c 'echo "'"$GLUETUN_ENV_FILE"'" > /var/lib/docker/gluetun.env'

echo "  - Create /var/lib/docker/proxy.env file."
PROXY_ENV_FILE=$(
    cat <<EOF
#@ HLS Proxy Config
HLS_PROXY_LOG_LEVEL=${HLS_PROXY_LOG_LEVEL:-1}
HLS_PROXY_HOST_IP=${HLS_PROXY_HOST_IP:?}
HLS_PROXY_PORT=${HLS_PROXY_PORT:-8080}
EOF
)
docker exec -i ${dind_continer_name:?} sh -c 'echo "'"$PROXY_ENV_FILE"'" > /var/lib/docker/proxy.env'

echo "  - Create /var/lib/docker/docker-compose.yml file."
COMPOSE_FILE=$(
    cat <<EOF
services:
  gluetun:
    image: qmcgaw/gluetun:latest
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    env_file: [gluetun.env]
    ports:
      - '${HLS_PROXY_PORT}:${HLS_PROXY_PORT}'
    dns:
      - 1.1.1.1
      - 8.8.4.4

  proxy:
    image: ${HLS_PROXY_DOCKER_IMAGE:-ghcr.io/josh5/warren-bank-hls-proxy:latest}
    restart: unless-stopped
    network_mode: service:gluetun
    env_file: [proxy.env]

  ipcheck:
    image: curlimages/curl:latest
    restart: unless-stopped
    network_mode: service:gluetun
    entrypoint: ["/bin/sh", "-c", "tail -f /dev/null"]
EOF
)
docker exec -i ${dind_continer_name:?} sh -c 'echo "'"$COMPOSE_FILE"'" > /var/lib/docker/docker-compose.yml'
