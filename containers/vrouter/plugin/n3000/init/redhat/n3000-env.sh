#/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh
source /etc/sysconfig/network-scripts/n3000/n3000-common.sh

function propagate_args() {
    declare -a env_vars=(
        N3000_VFs_NUM
        N3000_VFs_QUEUE_NUM
        N3000_VDPA_ENABLED
        N3000_VDPA_MAPPING_ENABLED
        N3000_INSERT_MODE
        N3000_PF0_DRIVER
        N3000_DROP_OFFLOAD_ENABLED
        N3000_AGING_LCORE_ENABLED
        N3000_CONF
        N3000_MODE
        N3000_TRIPLEO_L3MH_ROUTE
    )

    if [[ -f $env_file ]]; then
        rm $env_file
        touch $env_file
    fi

    for var in ${env_vars[@]}; do
        evaled_var="export $var=\"\${$var:-$(eval echo \${$var})}\""
        echo $evaled_var >> $env_file
    done
}

[[ ! -d "${ifcfg_dir}" ]] && mkdir -p "${ifcfg_dir}"

check_module 'intel-fpga-pci'
check_module 'i40e'

propagate_args

setup_factory_mode "${env_file}"

preconfig_dataplane "store" "${N3000_CONF}" "${env_file}" "${ifcfg_dir}"
