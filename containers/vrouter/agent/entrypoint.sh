#!/bin/bash

source /common.sh
source /agent-functions.sh
source /actions.sh

echo "INFO: agent started in $AGENT_MODE mode"

 # Clean up files and vhost0, when SIGQUIT signal by clean-up.sh
trap 'trap_vrouter_agent_quit' SIGQUIT

# Terminate process only.
# When a container/pod restarts it sends TERM and KILL signal.
# Every time container restarts we dont want to reset data plane
trap 'trap_vrouter_agent_term' SIGTERM SIGINT

# Send SIGHUP signal to child process
trap 'trap_vrouter_agent_hub' SIGHUP

vhost0_init $@

echo "DEBUG: Just before run agent"
run_agent $@
vrouter_agent_process=$(cat /var/run/vrouter-agent.pid)
echo "DEBUG: vrouter agent process outside fuction = $vrouter_agent_process"
wait $vrouter_agent_process