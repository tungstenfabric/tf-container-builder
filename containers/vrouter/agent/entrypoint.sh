#!/bin/bash
source /actions.sh

echo "INFO: agent started in $AGENT_MODE mode"

prepare_agent $@

create_agent_config $@

start_agent $@
