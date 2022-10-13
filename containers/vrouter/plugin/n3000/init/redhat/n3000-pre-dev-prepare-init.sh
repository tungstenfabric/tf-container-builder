#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh
source /etc/sysconfig/network-scripts/n3000/n3000-common.sh

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
    if [[ -f "${env_file}" ]]; then
        source_env
    else
        echo "WARNING: n3000-env file not found"
    fi
fi

[[ ! -d "${temp_work_dir}" ]] && mkdir -p "${temp_work_dir}"


fpga_mode_found="$(get_image_mode)"
if [[ "${fpga_mode_found}" == "user" ]]; then
    user_mode_found="$(verify_user_mode_config)"
    if [[ "${user_mode_found}" == "unconfigured" ]]; then
        setup_factory_mode "${env_file}"

        preconfig_dataplane "store" "${N3000_CONF}" "${env_file}" "${ifcfg_dir}"
    fi
fi
