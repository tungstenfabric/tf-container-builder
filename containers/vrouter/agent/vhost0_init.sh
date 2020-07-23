#!/bin/bash

source /common.sh
source /agent-functions.sh

echo "INFO: agent started in $AGENT_MODE mode"

vhost0_init $@

# We need this container after vhost0 setup for run next stage
tail -f /dev/null