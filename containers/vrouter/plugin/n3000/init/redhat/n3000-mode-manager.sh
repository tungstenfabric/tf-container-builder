#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh

export N3000_SWITCH_MODE=${N3000_SWITCH_MODE:-"user"}

function switch_to_user_mode(){
    local fpga_pci_addr=$(lspci -nnD | awk '/8086:0b30/ { print $1 }')
    local fpga_pci_addr_short=$(lspci -nnD | awk '/8086:0b30/ { print substr($1, 6,2) }')

    unbind_n3000_xxv710

    sleep 0.5
    PYTHONPATH=/var/lib/contrail/n3000/site_packages /var/lib/contrail/n3000/fecmode -B ${fpga_pci_addr_short} --rsu no

    sleep 0.5
    fpga_pci_addr=$(lspci -nnD | awk '/8086:0b30/ { print $1 }')
    unbind_n3000_xxv710

    sleep 0.5
    PYTHONPATH=/var/lib/contrail/n3000/site_packages /var/lib/contrail/n3000/rsu bmcimg "${fpga_pci_addr}"

    sleep 0.5
    unbind_n3000_xxv710
}

function switch_to_factory_mode(){
    local fpga_pci_addr=$(lspci -nnD | awk '/8086:0b30/ { print $1 }')
    local fpga_pci_addr_short=$(lspci -nnD | awk '/8086:0b30/ { print substr($1, 6,2) }')

    unbind_n3000_xxv710

    sleep 0.5

    PYTHONPATH=/var/lib/contrail/n3000/site_packages /var/lib/contrail/n3000/fecmode -B $(lspci -nnD | awk '/8086:0b30/ { print substr($1, 6,2) }') --rsu no
    unbind_n3000_xxv710

    sleep 0.5
    PYTHONPATH=/var/lib/contrail/n3000/site_packages /var/lib/contrail/n3000/rsu -f -d fpga $(lspci -nnD | awk '/8086:0b30/ { print $1 }')

    sleep 0.5
    unbind_n3000_xxv710
}

function main(){
    if [ "${N3000_SWITCH_MODE,,}" == "user" ]; then
        switch_to_user_mode
    elif [ "${N3000_SWITCH_MODE,,}" == "factory" ]; then
        switch_to_factory_mode
    fi
}

if [ "$0" = "$BASH_SOURCE" ] ; then
    main
fi
