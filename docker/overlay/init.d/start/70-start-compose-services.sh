#!/usr/bin/env bash
###
# File: 70-start-compose-services.sh
# Project: init.d
# File Created: Monday, 21st October 2024 11:40:21 am
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Monday, 4th November 2024 11:53:09 pm
# Modified By: Josh5 (jsunnex@gmail.com)
###

print_log info "Starting services"
${docker_compose_cmd:?} pull
if [ "${ALWAYS_FORCE_RECREATE:-}" = "true" ]; then
    print_log info "  - Forcing recreation of whole stack due to 'ALWAYS_FORCE_RECREATE' being set to '${ALWAYS_FORCE_RECREATE:-}'."
    ${docker_compose_cmd:?} up --detach --remove-orphans --force-recreate
else
    print_log info "  - Bring up existing stack"
    print_log info "    - > ${docker_compose_cmd:?} up --detach --remove-orphans"
    ${docker_compose_cmd:?} up --detach --remove-orphans
    print_log info "  - Ensure all services are started"
    print_log info "    - > ${docker_compose_cmd:?} start"
    ${docker_compose_cmd:?} start
fi
echo
