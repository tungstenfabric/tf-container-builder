#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh

temp_work_dir="/var/run/n3000"
perma_work_dir="/var/lib/contrail/n3000/"
env_file="${perma_work_dir}/n3000-env"
ifcfg_dir="${perma_data_dir}/ifcfgs"

. ${env_file}

/etc/sysconfig/network-scripts/n3000/n3000-offload-config.sh "disable" "${temp_work_dir}" "${ifcfg_dir}" "${env_file}"

preconfig_dataplane "noop" "${N3000_CONF}" "${env_file}" "${ifcfg_dir}"
