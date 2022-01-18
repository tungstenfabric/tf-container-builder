#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-driver-mgmt.sh

declare -a pf_pci_addr_list=( $(lspci -nnD | awk '/1af4:1041/ { print  $1 }') )

for pf_addr in ${pf_pci_addr_list[@]}; do
    sub_vendor=$(cat /sys/bus/pci/devices/${pf_addr}/subsystem_vendor)
    sub_device=$(cat /sys/bus/pci/devices/${pf_addr}/subsystem_device)
    if [[ "$sub_vendor" == "0x8086" && "$sub_device" == "0x15fe" ]]; then
        PF0_ADDR=${pf_addr}
        break
    fi
done

vf0_addr=$(realpath -e /sys/bus/pci/devices/${PF0_ADDR}/virtfn0 2>/dev/null | awk -F/ '{print $NF}')
current_vf0_driver_path=$(realpath -e /sys/bus/pci/devices/${vf0_addr}/driver/ 2>/dev/null)
current_vf0_driver=${current_vf0_driver_path##*/}

if [[ ${current_vf0_driver} != "virtio-pci" ]]; then
    echo "INFO: VF0 not bound to virtio-pci - rebinding"
    unbind_driver "${vf0_addr}"
    override_and_clean_driver "${vf0_addr}" "virtio-pci"
    echo "INFO: VF0 rebound to kernel"
fi

rm -f /var/run/vrouter/${vf0_addr}
