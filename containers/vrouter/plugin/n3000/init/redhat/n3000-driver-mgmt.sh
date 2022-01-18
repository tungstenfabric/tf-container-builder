#!/usr/bin/env bash

function unbind_driver()
{
# Expected argument:
# $1 - PCI address of device to unbind
    local addr=$1
    if [[ -n "${addr}" && -e "/sys/bus/pci/devices/${addr}/driver/${addr}" ]]; then
        echo "INFO: Unbinding ${addr} device from its driver"
        echo "${addr}" > /sys/bus/pci/devices/"${addr}"/driver/unbind
    else
        echo "WARNING: Device ${addr} has no driver to unbind from"
    fi
}

function override_driver()
{
    local addr=$1
    local driver=$2
    if [[ -n "${addr}" && -n "${driver}" && -e "/sys/bus/pci/devices/${addr}/driver_override" ]]; then
        echo "INFO: Binding device ${addr} to driver ${driver} by using driver_override"
        echo "${driver}" > /sys/bus/pci/devices/"${addr}"/driver_override
        echo "${addr}" > /sys/bus/pci/drivers_probe
    else
        echo "WARNING: No driver_override"
    fi
}

function override_and_clean_driver()
{
    local addr=$1
    local driver=$2
    if [[ -n "${addr}" && -n "${driver}" && -e "/sys/bus/pci/devices/${addr}/driver_override" ]]; then
        echo "INFO: Binding device ${addr} to driver ${driver} by using driver_override"
        echo "${driver}" > /sys/bus/pci/devices/"${addr}"/driver_override
        echo "${addr}" > /sys/bus/pci/drivers_probe
        echo "" > /sys/bus/pci/devices/"${addr}"/driver_override
    else
        echo "WARNING: No driver_override"
    fi
}

function bind_driver()
{
    # Expected arguments:
    # $1 - PCI address of device
    # $2 - driver to which device will be bound
    local addr=$1
    local driver=$2
    local current_driver=$(lspci -s "$addr" -k | awk '/Kernel driver in use/ { print $5}')
    if [[ -n "${addr}" && -n "${driver}" && -e "/sys/bus/pci/drivers/${driver}" && -z "${current_driver}" ]]; then
        echo "INFO: Binding ${driver} driver with ${addr} device"
        echo -n "${addr}" > /sys/bus/pci/drivers/"${driver}"/bind
    else
        echo "WARNING: Not possible to bind driver ${driver} to device ${addr}"
    fi
}

function check_module() {
    local driver=$1

    if [[ "${driver}" == "unbound" ]] ; then
        return
    fi

    if ! modprobe -i "${driver}" ;  then
        modprobe "${driver}"
        echo "INFO: Loading kernel module: ${driver}"
    fi
}

function check_modules()
{
    local pf0_driver=$1
    local pf1_driver=$2
    local vfs_driver=$3

    check_module ${pf0_driver}
    check_module ${pf1_driver}
    check_module ${vfs_driver}
}

function unbind_n3000_xxv710()
{
    local -a xxv710_pci_addr
    local current_device_ifname
    # Get PCI addresses of XXV710 Intel(R) FPGA PAC N3000 devices
    xxv710_pci_addr=( $(lspci -d :0d58 -D | awk '{print $1}') )
    echo "INFO: XXV710 PCI addresses: ${xxv710_pci_addr[@]}"
    if [[ ${xxv710_pci_addr[@]} ]]; then
    for pci_addr in ${xxv710_pci_addr[@]};
    do
        if [[ -d "/sys/bus/pci/devices/${pci_addr}/net" ]]; then
        current_device_ifname=$(ls /sys/bus/pci/devices/${pci_addr}/net 2>/dev/null)
        if [[ -n "${current_device_ifname}" && -f "/etc/sysconfig/network-scripts/ifcfg-${current_device_ifname}" ]]; then
            rm -f /etc/sysconfig/network-scripts/ifcfg-"${current_device_ifname}"
        fi
        fi
        unbind_driver "${pci_addr}"
    done
    else
        echo "No devices to unbind."
    fi
}
