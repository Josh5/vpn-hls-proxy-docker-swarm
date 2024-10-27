#!/usr/bin/env bash
###
# File: 20-dind-container-stop.sh
# Project: init.d
# File Created: Monday, 21st October 2024 11:56:54 am
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Sunday, 27th October 2024 2:39:10 pm
# Modified By: Josh5 (jsunnex@gmail.com)
###

print_log info "Stopping DIND container ${dind_continer_name:?}"
docker stop --time 120 ${dind_continer_name:?} &>/dev/null || true
echo

print_log info "Removing DIND network ${dind_bridge_network_name:?}"
docker network rm "${dind_bridge_network_name:?}" &>/dev/null || true
echo

print_log info "Removing DIND volume ${dind_cache_volume_name:?}"
docker volume rm "${dind_cache_volume_name:?}" &>/dev/null || true
echo
