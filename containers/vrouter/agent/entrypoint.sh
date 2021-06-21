#!/bin/bash

# save container output to log
log_dir=${CONTAINER_LOG_DIR:-${LOG_DIR:-'/var/log/contrail'}/${NODE_TYPE}-${SERVICE_NAME}}
mkdir -p $log_dir
log_file="$log_dir/vrouter-agent-entrypoint.log"
touch "$log_file"
exec &> >(tee -a "$log_file")
chmod 600 $log_file
echo "INFO: =================== $(date) ==================="

source /actions.sh

echo "INFO: agent started in $AGENT_MODE mode"

prepare_agent $@

create_agent_config $@

start_agent $@
