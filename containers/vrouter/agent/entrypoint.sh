#!/bin/bash

source /common.sh
source /agent-functions.sh
source /actions.sh

echo "INFO: agent started in $AGENT_MODE mode"

set_traps

vhost0_init $@

run_agent $@

wait $(cat /var/run/vrouter-agent.pid)