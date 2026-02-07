#!/usr/bin/env bash
###
# File: entrypoint.sh
# Project: overlay
# File Created: Friday, 18th October 2024 5:05:51 pm
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Sunday, 27th October 2024 3:25:23 pm
# Modified By: Josh5 (jsunnex@gmail.com)
###
set -eu

################################################
# --- Export config
#
export docker_version=$(docker --version | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")
export dind_continer_name="${STACK_NAME:?}-dind"
export dind_bridge_network_name="${STACK_NAME:?}-dind-net"
export dind_cache_volume_name="${STACK_NAME:?}-docker-cache"
export custom_docker_network_name="${STACK_NAME:?}-private-net"

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
# --- IP helpers
#
_ip_sources=(
    "https://ifconfig.co/ip"
    "https://ipinfo.io/ip"
    "https://api.ipify.org"
)

_is_ipv4() {
    local ip="${1:-}"
    [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r o1 o2 o3 o4 <<< "${ip}"
    for o in "${o1}" "${o2}" "${o3}" "${o4}"; do
        [ "${o}" -le 255 ] || return 1
    done
}

_fetch_manager_ip() {
    local url ip
    for url in "${_ip_sources[@]}"; do
        ip=$(curl -4 -fsS --max-time 10 "${url}" 2>/dev/null || true)
        ip=$(echo "${ip}" | tr -d ' \r\n')
        if _is_ipv4 "${ip}"; then
            echo "${ip}"
            return 0
        fi
    done
    return 1
}

_fetch_proxy_ip() {
    local url ip
    for url in "${_ip_sources[@]}"; do
        ip=$(${docker_compose_cmd:?} exec -T ipcheck sh -c "curl -4 -fsS --max-time 10 \"${url}\"" 2>/dev/null || true)
        ip=$(echo "${ip}" | tr -d ' \r\n')
        if _is_ipv4 "${ip}"; then
            echo "${ip}"
            return 0
        fi
    done
    return 1
}

################################################
# --- Create TERM monitor
#
_term() {
    echo
    echo -e "\e[35m[ Stopping manager service ]\e[0m"
    if [ "${KEEP_ALIVE}" = "false" ]; then
        echo "  - The 'KEEP_ALIVE' env variable is set to ${KEEP_ALIVE:?}. Running all shutdown scripts."
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

VPN_HEALTH_STARTUP_GRACE="${VPN_HEALTH_STARTUP_GRACE:-60}"
VPN_HEALTH_INTERVAL="${VPN_HEALTH_INTERVAL:-60}"
VPN_HEALTH_MAX_FAILS="${VPN_HEALTH_MAX_FAILS:-3}"
VPN_HEALTH_FAIL_ACTION="${VPN_HEALTH_FAIL_ACTION:-restart-stack}"
VPN_HEALTH_HOST_IP_REFRESH="${VPN_HEALTH_HOST_IP_REFRESH:-300}"

host_ip=""
host_ip_last_refresh=0
vpn_fail_count=0
vpn_health_next_check_ts=0

################################################
# --- Create compose stack monitor
#
_stack_monitor() {
    print_log info "Waiting for child services to exit"
    cd /config/${STACK_NAME:?}/
    while true; do
        now_ts=$(date +%s)
        if [ "${vpn_health_next_check_ts:?}" -eq 0 ]; then
            vpn_health_next_check_ts=$((now_ts + VPN_HEALTH_STARTUP_GRACE))
            print_log info "Waiting ${VPN_HEALTH_STARTUP_GRACE:?}s before VPN health enforcement..."
        fi

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

        if [ -z "${host_ip:-}" ] || [ $((now_ts - host_ip_last_refresh)) -ge "${VPN_HEALTH_HOST_IP_REFRESH:?}" ]; then
            print_log info "Checking host external IP..."
            host_ip=$(_fetch_manager_ip || true)
            if [ -n "${host_ip:-}" ]; then
                print_log info "  - Host IP: ${host_ip:-}"
                host_ip_last_refresh=${now_ts:?}
            else
                print_log info "  - Unable to fetch host IP. Will retry."
            fi
        fi

        if [ "${now_ts:?}" -lt "${vpn_health_next_check_ts:?}" ]; then
            print_log info "Skipping VPN health check until grace period ends."
            sleep ${VPN_HEALTH_INTERVAL:?} &
            wait $!
            echo
            continue
        fi

        print_log info "Checking VPN external IP..."
        vpn_ip=$(_fetch_proxy_ip || true)
        if [ -z "${vpn_ip:-}" ]; then
            print_log error "  - Unable to fetch VPN IP from proxy container."
            vpn_fail_count=$((vpn_fail_count + 1))
        elif [ -n "${host_ip:-}" ] && [ "${vpn_ip:-}" = "${host_ip:-}" ]; then
            print_log error "  - VPN IP matches host IP (${vpn_ip:-}). Leak suspected."
            vpn_fail_count=$((vpn_fail_count + 1))
        else
            print_log info "  - VPN IP: ${vpn_ip:-}"
            vpn_fail_count=0
        fi

        if [ "${vpn_fail_count:?}" -ge "${VPN_HEALTH_MAX_FAILS:?}" ]; then
            print_log error "VPN health check failed ${vpn_fail_count:?} times. Action: ${VPN_HEALTH_FAIL_ACTION:?}"
            case "${VPN_HEALTH_FAIL_ACTION:?}" in
            exit)
                exit 123
                ;;
            restart-stack)
                print_log error "Restarting stack due to VPN health failure"
                ${docker_compose_cmd:?} down --remove-orphans || true
                ${docker_compose_cmd:?} up --detach --remove-orphans || true
                vpn_fail_count=0
                vpn_health_next_check_ts=$(( $(date +%s) + VPN_HEALTH_STARTUP_GRACE ))
                ;;
            *)
                print_log error "Unknown VPN_HEALTH_FAIL_ACTION '${VPN_HEALTH_FAIL_ACTION:?}'. Exiting."
                exit 123
                ;;
            esac
        fi

        sleep ${VPN_HEALTH_INTERVAL:?} &
        wait $!
        echo
    done
}
sleep 10 &
wait $!

${docker_compose_cmd:?}  logs -f &
log_pid=$?

print_log info "Waiting 10s before starting stack monitor..."
sleep 10 &
wait $!

_stack_monitor
