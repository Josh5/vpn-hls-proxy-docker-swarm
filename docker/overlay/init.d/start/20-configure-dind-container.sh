#!/usr/bin/env bash
###
# File: 20-configure-dind-container.sh
# Project: init.d
# File Created: Monday, 21st October 2024 10:37:05 am
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Sunday, 27th October 2024 3:12:06 pm
# Modified By: Josh5 (jsunnex@gmail.com)
###

print_log info "Configure DIND"
print_log info "  - Ensure DIND network exists..."
existing_network=$(docker network ls 2>/dev/null | grep "${dind_bridge_network_name:?}" || echo "")
if [ "X${existing_network}" = "X" ]; then
    print_log info "    - Creating private network for DIND container..."
    docker network create -d bridge "${dind_bridge_network_name:?}"
else
    print_log info "    - A private network for DIND named ${dind_bridge_network_name:?} already exists!"
fi
echo

print_log info "  - Ensure DIND volumes exists..."
# Check if the 'docker-cache' volume exists
if ! docker volume inspect "${dind_cache_volume_name:?}" >/dev/null 2>&1; then
    print_log info "    - Creating volume: ${dind_cache_volume_name:?}"
    docker volume create "${dind_cache_volume_name:?}"
fi

print_log info "  - Set DIND daemon args..."
dind_daemon_args=""
dind_daemon_args="${dind_daemon_args:-} --ipv6=false"
if [ -n "${DIND_MTU:-}" ]; then
    dind_daemon_args="${dind_daemon_args:-} --mtu=${DIND_MTU:?}"
fi

print_log info "  - Calculate DIND container CPU limits..."
if [ -n "${DIND_CPU_PERCENT:-}" ]; then
    if [[ "${DIND_CPU_PERCENT:?}" =~ ^[0-9]+$ ]] && [ "${DIND_CPU_PERCENT:?}" -ge 1 ] && [ "${DIND_CPU_PERCENT:?}" -le 100 ]; then
        print_log info "    - The DIND_CPU_PERCENT variable is a valid number between 1 and 100."
        if [ "${DIND_CPU_PERCENT:?}" = "100" ]; then
            # 100 is not actually a valid number. Lets just drop that down a tad
            DIND_CPU_PERCENT=99
        fi
    else
        print_log info "    - The DIND_CPU_PERCENT variable is not a valid number between 1 and 100. Defaulting to 75."
        DIND_CPU_PERCENT=75
    fi
else
    print_log info "    - The DIND_CPU_PERCENT variable has not been provided. Defaulting to 75."
    DIND_CPU_PERCENT=75
fi
TOTAL_CPUS=$(nproc)
print_log info "    - Calculating CPU Quota from ${DIND_CPU_PERCENT:?}% of a total ${TOTAL_CPUS:?} CPUs"
CPU_PERIOD=100000
CPU_QUOTA=$(echo "${CPU_PERIOD:?} * $(nproc) * 0.${DIND_CPU_PERCENT:?}" | bc)
CPU_QUOTA=${CPU_QUOTA%.*}
print_log info "    - CPU Quota: ${CPU_QUOTA:?}/${CPU_PERIOD:?}"

print_log info "  - Configure DIND container run aliases..."
DIND_RUN_CMD="docker run --privileged -d --rm --name ${dind_continer_name:?} \
    --memory ${DIND_MEMLIMIT:-0} \
    --cpu-shares ${DIND_CPU_SHARES:-512} \
    --cpu-period ${CPU_PERIOD:?} \
    --cpu-quota ${CPU_QUOTA:?} \
    --env DOCKER_DRIVER=overlay2 \
    --volume ${dind_cache_volume_name:?}:/var/lib/docker \
    --network ${dind_bridge_network_name:?} \
    --network-alias ${dind_continer_name:?} \
    --publish ${HLS_PROXY_PORT:-8080}:${HLS_PROXY_PORT:-8080} \
    docker:${docker_version:?}-dind ${dind_daemon_args:-}"

print_log info "  - Writing DIND container config to env file"
echo "" >${manager_config_path:?}/new-dind-run-config.env
echo "docker_version=${docker_version:?}" >>${manager_config_path:?}/new-dind-run-config.env
echo "DIND_RUN_CMD=${DIND_RUN_CMD:?}" >>${manager_config_path:?}/new-dind-run-config.env

print_log info "  - Checking if config has changed since last run"
if ! cmp -s "${manager_config_path:?}/new-dind-run-config.env" "${manager_config_path:?}/current-dind-run-config.env"; then
    print_log info "    - Env has changed. Stopping up old dind container due to possible config update"
    docker stop --time 120 ${dind_continer_name} &>/dev/null || true
    docker rm ${dind_continer_name} &>/dev/null || true
    mv -fv "${manager_config_path:?}/new-dind-run-config.env" "${manager_config_path:?}/current-dind-run-config.env"
else
    print_log info "    - Env has not changed."
fi

print_log info "  - Ensure DIND container is running"
if ! docker ps | grep -q ${dind_continer_name}; then
    print_log info "    - Fetching latest docker in docker image 'docker:${docker_version:?}-dind'"
    docker pull docker:${docker_version:?}-dind
    echo

    print_log info "    - Creating DIND container"
    ${DIND_RUN_CMD:?}
    sleep 5 &
    wait $!
    echo
else
    print_log info "    - DIND container already running"
fi
