#!/usr/bin/env bash

if [[ -f /etc/sysconfig/network-scripts/n3000/n3000-env ]]; then
    . /etc/sysconfig/network-scripts/n3000/n3000-env
fi

export N3000_VFs_NUM=${N3000_VFs_NUM:-"16"}
export N3000_VFs_QUEUE_NUM=${N3000_VFs_QUEUE_NUM:-"1"}
export N3000_VDPA_ENABLED=${N3000_VDPA_ENABLED:-"true"}
export N3000_BONDING_MODE=${N3000_BONDING_MODE:-"2"}
export N3000_VDPA_MAPPING_ENABLED=${N3000_VDPA_MAPPING_ENABLED:-"true"}
export N3000_INSERT_MODE=${N3000_INSERT_MODE:-"csr"}
export N3000_PF0_DRIVER=${N3000_PF0_DRIVER:-"pci-pf-stub"}
export N3000_DROP_OFFLOAD_ENABLED=${N3000_DROP_OFFLOAD_ENABLED:-"false"}
export N3000_AGING_LCORE_ENABLED=${N3000_AGING_LCORE_ENABLED:-"true"}
export N3000_CUSTOM_VF0_NAME=${N3000_CUSTOM_VF0_NAME:-"n3kvf0"}

binding_dir="/var/lib/contrail/vrouter/n3000"
src_dir="/usr/src/n3000"

mkdir -p ${binding_dir} || true
rm ${binding_dir}/args || true

. /etc/sysconfig/network-scripts/n3000/n3000-offload-config.sh ${binding_dir}

export PHYSICAL_INTERFACE=$(cat ${binding_dir}/vf0_ifname)
export DPDK_COMMAND_ADDITIONAL_ARGS="$(cat ${binding_dir}/args) ${DPDK_COMMAND_ADDITIONAL_ARGS:-""}"
if [[ -n ${BIND_INT} ]]; then
    export BIND_INT="$(cat ${binding_dir}/vf0_pci)"
    sed -i "s/BIND_INT=.*/BIND_INT=${BIND_INT}/g" /etc/sysconfig/network-scripts/ifcfg-vhost0
fi
