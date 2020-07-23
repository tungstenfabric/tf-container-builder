#!/bin/bash

source /common.sh
source /agent-functions.sh

echo "INFO: agent started in $AGENT_MODE mode"

function trap_vrouter_agent_quit() {
    local res=0
    if ! term_process $vrouter_agent_process ; then
        echo "ERROR: Failed to stop agent process"
        res=1
    fi
    remove_vhost0
    cleanup_vrouter_agent_files
    exit $res
}

function trap_vrouter_agent_term() {
    term_process $vrouter_agent_process
    exit $?
}

function trap_vrouter_agent_hub() {
    send_sighup_child_process $vrouter_agent_process
}

# Clean up files and vhost0, when SIGQUIT signal by clean-up.sh
trap 'trap_vrouter_agent_quit' SIGQUIT

# Terminate process only.
# When a container/pod restarts it sends TERM and KILL signal.
# Every time container restarts we dont want to reset data plane
trap 'trap_vrouter_agent_term' SIGTERM SIGINT

# Send SIGHUP signal to child process
trap 'trap_vrouter_agent_hub' SIGHUP

vhost0_init_stage $@

# We need this container after vhost0 setup for run next stage
tail -f /dev/null