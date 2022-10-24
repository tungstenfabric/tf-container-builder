#!/usr/bin/env bash

export N3000_VFs_NUM=${N3000_VFs_NUM:-"16"}
export N3000_VFs_QUEUE_NUM=${N3000_VFs_QUEUE_NUM:-"1"}
export N3000_VDPA_ENABLED=${N3000_VDPA_ENABLED:-"true"}
export N3000_CONF=${N3000_CONF:-"single"}
export N3000_VDPA_MAPPING_ENABLED=${N3000_VDPA_MAPPING_ENABLED:-"true"}
export N3000_INSERT_MODE=${N3000_INSERT_MODE:-"csr"}
export N3000_PF0_DRIVER=${N3000_PF0_DRIVER:-"pci-pf-stub"}
export N3000_DROP_OFFLOAD_ENABLED=${N3000_DROP_OFFLOAD_ENABLED:-"false"}
export N3000_AGING_LCORE_ENABLED=${N3000_AGING_LCORE_ENABLED:-"true"}
export N3000_MODE=${N3000_MODE:-"user"}

source /etc/sysconfig/network-scripts/n3000/n3000-common.sh

mkdir -p ${temp_work_dir} || true
rm ${temp_work_dir}/args || true

/etc/sysconfig/network-scripts/n3000/n3000-offload-config.sh "enable" "${temp_work_dir}" "${ifcfg_dir}" "${env_file}"

[[ -f "${dev_state_restored_lock_file}" ]] && rm "${dev_state_restored_lock_file}"

export DPDK_COMMAND_ADDITIONAL_ARGS="${DPDK_COMMAND_ADDITIONAL_ARGS} $(cat ${temp_work_dir}/args)"
