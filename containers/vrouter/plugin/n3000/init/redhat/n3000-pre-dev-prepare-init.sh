#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh

perma_work_dir="/var/lib/contrail/n3000/"
temp_work_dir="/var/run/n3000"
n3000_env_file="${perma_work_dir}/n3000-env"
init_lock_file="${perma_work_dir}/n3000-plugin-init-done"

function source_env() {
    if [[ -f "${n3000_env_file}" ]]; then
        echo "INFO: Sourcing env"
        echo "INFO: Source env file content:"
        echo "$(cat ${n3000_env_file})"
        . "${n3000_env_file}"
    fi
}

if [[ -f "${init_lock_file}" ]]; then
    source_env
else
    # first time run scenario
    for i in {0..300} ; do
        echo "INFO: Waiting for n3000-init container to finish...($i/300)"
        [[ -f "${init_lock_file}" ]] && break;
        if (( i == 300 )) ; then
            echo "ERROR: Time for n3000-init container to finish exceeded."
            exit -1
        fi
        sleep 1
    done

    echo "Waiting for n3000-init container to finish done."
    if [[ -f "${n3000_env_file}" ]]; then
        source_env
    else
        echo "WARNING: n3000-env file not found"
    fi
fi

mkdir -p "${temp_work_dir}" || true
