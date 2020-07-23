#!/bin/bash

source /common.sh
source /agent-functions.sh

echo "INFO: agent started in $AGENT_MODE mode"

set_traps

vhost0_init $@

wait $(run_agent $@)