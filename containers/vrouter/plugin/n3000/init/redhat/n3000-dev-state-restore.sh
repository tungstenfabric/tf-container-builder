#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh
source /etc/sysconfig/network-scripts/n3000/n3000-common.sh

echo "INFO: n3000-dev-state-restore.sh called"

[[ -f "${dev_state_restored_lock_file}" ]] && \
    echo "INFO: Dev state restore already called for this deinitialization procedure. Skipping next invocation." && exit

touch "${dev_state_restored_lock_file}"

source_env

/etc/sysconfig/network-scripts/n3000/n3000-offload-config.sh "disable" "${temp_work_dir}" "${ifcfg_dir}" "${env_file}"

preconfig_dataplane "restore" "${N3000_CONF}" "${env_file}" "${ifcfg_dir}"

rebind_factory "vfio-pci"
