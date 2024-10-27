#!/usr/bin/env bash
###
# File: entrypoint.sh
# Project: overlay
# File Created: Friday, 18th October 2024 5:05:51 pm
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Sunday, 27th October 2024 2:58:19 pm
# Modified By: Josh5 (jsunnex@gmail.com)
###
set -eu

################################################
# --- Export config
#
export docker_version=$(docker --version | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")
export dind_continer_name="vpn-hls-proxy-swarm-dind"
export dind_bridge_network_name="vpn-hls-proxy-swarm-dind-net"
export dind_cache_volume_name="${STACK_NAME:?}-docker-cache"
export custom_docker_network_name="vpn-hls-proxy-swarm-private-net"

export cmd_prefix="docker exec --workdir=/var/lib/docker ${dind_continer_name:?}"
export docker_cmd="${cmd_prefix:?} docker"
export docker_compose_cmd="${cmd_prefix:?} docker compose --project-name ${STACK_NAME:?}"

export manager_config_path="/config/${STACK_NAME:?}"
mkdir -p ${manager_config_path:?}

################################################
# --- Create Logging Function
#
print_log() {
    timestamp=$(date +'%Y-%m-%d %H:%M:%S %z')
    pid="$$"
    level="$1"
    shift
    message="$*"
    echo "[${timestamp}] [${pid}] [${level}] ${message}"
}

################################################
# --- Create TERM monitor
#
_term() {
    echo
    echo -e "\e[35m[ Stopping manager service ]\e[0m"
    if [ "X${log_pid:-}" != "X" ]; then
        kill ${log_pid:-}
    fi
    if [ "${KEEP_ALIVE}" = "false" ]; then
        echo "  - The 'KEEP_ALIVE' env variable is set to ${KEEP_ALIVE:?}. Running all shutdown scripts"
        # Run all stop scripts
        for stop_script in /init.d/stop/*.sh; do
            if [ -f ${stop_script:?} ]; then
                echo
                echo -e "\e[33m[ ${stop_script:?}: executing... ]\e[0m"
                sed -i 's/\r$//' "${stop_script:?}"
                source "${stop_script:?}"
            fi
        done
        echo
    else
        echo "  - The 'KEEP_ALIVE' env variable is set to ${KEEP_ALIVE:?}. Stopping manager only."
    fi
    exit 0
}
trap _term SIGTERM SIGINT

################################################
# --- Run through startup init scripts
#
echo
echo -e "\e[35m[ Running startup scripts ]\e[0m"
for start_script in /init.d/start/*.sh; do
    if [ -f ${start_script:?} ]; then
        echo
        echo -e "\e[34m[ ${start_script:?}: executing... ]\e[0m"
        sed -i 's/\r$//' "${start_script:?}"
        source "${start_script:?}"
    fi
done

################################################
# --- Create compose stack monitor
#
_stack_monitor() {
    print_log info "Waiting for child services to exit"
    cd /config/${STACK_NAME:?}/
    while true; do
        # Check if any service has exited with a non-zero status code
        print_log info "Check if any service has exited with a non-zero status code"
        exited_services=$(${docker_compose_cmd:?} ps --all --filter "status=exited" | grep -v "^NAME" || true)
        if [ "X${exited_services}" != "X" ]; then
            print_log error "  - Some services have exited. Exit!"
            exit 123
        else
            print_log info "  - All services are running and healthy."
        fi

        # Check if the main services have exited
        print_log info "Check that the main services are still up"
        services="$(${docker_compose_cmd:?} config --services)"
        # Loop through each service to check its status
        for service in $services; do
            # Use docker compose --project-name ${STACK_NAME:?} ps to check if the service is running
            service_status=$(${docker_compose_cmd:?} ps --format "table {{.Service}} {{.Status}}" | grep $service || true)
            case $service_status in
            *Up*)
                print_log info "  - Service $service is up and running."
                continue
                ;;
            *)
                print_log error "  - Service $service is NOT running. Exit!"
                exit 123
                ;;
            esac
        done

        print_log info "Checking HLS Proxy external IP..."
        external_ip=$(${docker_compose_cmd:?} exec proxy curl -4 -s -m 10 ifconfig.co || true)
        if [ "X${external_ip:-}" != "X" ]; then
            print_log info "  - Current IP: ${external_ip:-}"
        else
            print_log info "  - Unable to fetch current IP ${external_ip:-} from container proxy..."
        fi
        sleep 60 &
        wait $!
        echo
    done
}
sleep 10 &
wait $!

${docker_compose_cmd:?}  logs -f &
log_pid=$?

_stack_monitor
