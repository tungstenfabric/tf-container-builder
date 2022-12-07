#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh
source /etc/sysconfig/network-scripts/n3000/n3000-common.sh

export N3000_SWITCH_MODE=${N3000_SWITCH_MODE:-"user"}

function restore_clean_device_state() {
    local n3k_virtio_dev_addr="$(lspci -nnD | awk '/1af4:1041/ { print $1 }')"
    local pf1_pci_addr="$(lspci -nnD | awk '/8086:15fe/ { print  $1 }')"

    echo "INFO(n3000-mode-manager): Restoring clean device state..."
    for n3k_virtio_dev in ${n3k_virtio_dev_addr}; do
        unbind_driver "${n3k_virtio_dev}"
    done

    unbind_driver ${pf1_pci_addr}

    unbind_n3000_xxv710

    sleep 0.5

    echo "INFO(n3000-mode-manager): Restoring clean device state done"
}

function invoke_fecmode() {
    local fpga_pci_addr_short="$(lspci -nnD | awk '/8086:0b30/ { print substr($1, 6,2) }')"

    restore_clean_device_state

    echo "INFO(n3000-mode-manager): Invoking fecmode..."
    PYTHONPATH=/var/lib/contrail/n3000/site_packages /var/lib/contrail/n3000/fecmode -B "${fpga_pci_addr_short}" no

    restore_clean_device_state
}

function switch_to_user_mode(){
    invoke_fecmode

    local fpga_pci_addr="$(lspci -nnD | awk '/8086:0b30/ { print $1 }')"

    echo "INFO(n3000-mode-manager): Invoking rsu..."
    PYTHONPATH=/var/lib/contrail/n3000/site_packages /var/lib/contrail/n3000/rsu bmcimg "${fpga_pci_addr}"

    restore_clean_device_state
}

function switch_to_factory_mode(){
    invoke_fecmode

    local fpga_pci_addr="$(lspci -nnD | awk '/8086:0b30/ { print $1 }')"

    echo "INFO(n3000-mode-manager): Invoking rsu..."
    PYTHONPATH=/var/lib/contrail/n3000/site_packages /var/lib/contrail/n3000/rsu -f -d fpga "${fpga_pci_addr}"

    restore_clean_device_state
}

function main() {
    local requested_mode="${N3000_SWITCH_MODE,,}"

    echo "INFO(n3000-mode-manager): started"
    echo "INFO(n3000-mode-manager): Switching fpga to ${N3000_SWITCH_MODE,,} mode"

    if [ "${requested_mode}" == "user" ]; then
        switch_to_user_mode
    elif [ "${requested_mode}" == "factory" ]; then
        switch_to_factory_mode
    fi

    echo "INFO(n3000-mode-manager): done"
}

if [ "$0" = "$BASH_SOURCE" ] ; then
    main
fi
