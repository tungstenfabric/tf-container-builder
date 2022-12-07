#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-common.sh

function source_env() {
    if [[ -f "${env_file}" ]]; then
        echo "INFO: Sourcing env"
        echo "INFO: Source env file content:"
        echo "$(cat ${env_file})"
        . "${env_file}"
    fi
}

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

function get_pf0_address() {
    declare -a pf_pci_addr_list=( $(lspci -nnD | awk '/1af4:1041/ { print  $1 }') )

    for pf_addr in ${pf_pci_addr_list[@]}; do
        sub_vendor=$(cat /sys/bus/pci/devices/${pf_addr}/subsystem_vendor)
        sub_device=$(cat /sys/bus/pci/devices/${pf_addr}/subsystem_device)
        if [[ "$sub_vendor" == "0x8086" && "$sub_device" == "0x15fe" ]]; then
            echo -n "${pf_addr}"
            return
        fi
    done
}

function get_image_mode {
    local fpga_loaded_image_file="/sys/class/fpga/intel-fpga-dev.0/intel-fpga-fme.0/spi-altera.0.auto/spi_master/spi0/spi0.0/fpga_flash_ctrl/fpga_image_load"

    if [[ ! -f "${fpga_loaded_image_file}" ]]; then
        #TODO: If this happens, device is in bad state
        echo -n "ERROR: FPGA bad state"
        exit -1
    fi

    local mode_id="$(cat ${fpga_loaded_image_file})"

    if [[ "${mode_id}" == "0" ]]; then
        echo -n "factory"
    else
        echo -n "user"
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
            echo "INFO: Moving ifcfg for ${current_device_ifname} to ${ifcfg_dir}"

            [[ ! -f "${ifcfg_dir}/ifcfg-${current_device_ifname}" ]] && \
                mv -f "/etc/sysconfig/network-scripts/ifcfg-${current_device_ifname}" "${ifcfg_dir}/ifcfg-${current_device_ifname}"
        fi
        fi
        unbind_driver "${pci_addr}"
    done
    else
        echo "No devices to unbind."
    fi
}

function get_config() {
    local n3000_conf=$1
    local config_type=$(echo ${n3000_conf} | awk -F';' '{print $1}')
    local user_params=$(echo ${n3000_conf} | awk -F';' '{print $2}')

    local config
    declare -A config
    declare -A possible_config_params=(
        ["single"]="physical_interface=net_n3k0_phy0"
        ["bonding"]="bonding_mode=2 xmit_policy=l34 lacp_rate=1"
        ["l3mh"]="phy0_ifname=n3kphy0 phy1_ifname=n3kphy1"
    )

    if [[ -z ${possible_config_params[$config_type]} ]]
    then
        #echo "ERROR: Config type ${config_type} doesn't exist"
        exit 1
    fi

    local key=''
    local value=''
    #echo "INFO: Prepare parse map for N3000_CONF"
    for param in ${possible_config_params[$config_type]}; do
        key=$(echo ${param} | awk -F'=' '{print $1}')
        value=$(echo ${param} | awk -F'=' '{print $2}')
        #echo "INFO: expected param=${param}; key=$key; value=$value"
        config+=( [$key]=$value )
    done

    #echo "INFO: Parsing N3000_CONF"
    for param in ${user_params}; do
        key=$(echo ${param} | awk -F'=' '{print $1}')
        value=$(echo ${param} | awk -F'=' '{print $2}')
        #echo "INFO: provided param=${param}; key=$key; value=$value"
        if [[ ! -z ${config[$key]} ]]; then
            #echo "INFO: adding param with key=$key; value=$value"
            config[$key]=$value
        fi
    done

    #echo "INFO: Parsing done:"
    declare -p config
}

function restore_ifcfg() {
    local ifcfg_dir=$1

    if [[ ! -d "$ifcfg_dir" ]]; then
        echo "WARNING: $ifcfg_dir not found"
        return
    fi

    shopt -s nullglob

    for ifcfg_file in $ifcfg_dir/*; do
        local ifile="$(echo $ifcfg_file | awk -F/ '{ print $NF; }')"

        if [[ -f "/etc/sysconfig/network-scripts/$ifile" ]]; then
            echo "INFO: /etc/sysconfig/network-scripts/$ifile exists - skipping"
            continue
        fi

        cp "$ifcfg_file" "/etc/sysconfig/network-scripts/$ifile"

        echo "INFO: /etc/sysconfig/network-scripts/$ifile restored"
    done

    shopt -u nullglob
}

function set_network_info_for_device {
    local ifname=$1
    local pci_addr=$2
    local ifcfg_file="/etc/sysconfig/network-scripts/ifcfg-${ifname}"

    if [[ -f "${ifcfg_file}" ]]; then
        local mac="$(cat ${ifcfg_file} | awk -F= '/MACADDR/ { print $2; }')"

        [[ -n "${mac}" ]] && ip link set dev "${ifname}" address "${mac}"
    fi
}

function preconfig_dataplane() {
    function prepare_l3mh {
        echo "INFO: Preparing l3mh init state for vRouter."

        for i in $(seq 0 1); do
            local phy_addr="$(lspci -d :0d58 -D | awk '{print $1}' | awk "NR == $(( i + 1 ))")"
            local phy_ifname=$(realpath -e /sys/bus/pci/devices/${phy_addr}/net/* 2>/dev/null | awk -F/ '{print $NF}')
            local ifname_key="phy${i}_ifname"
            local requested_ifname="${config[${ifname_key}]}"
            echo "INFO: phy_addr=$phy_addr, ifname found: $phy_ifname, requested ifname: $requested_ifname"
            ip link set "${phy_ifname}" down
            ip link set "${phy_ifname}" name "${requested_ifname}"

            set_network_info_for_device "${requested_ifname}" "${phy_addr}"

            [ -n "${N3000_TRIPLEO_L3MH_ROUTE}" ] && echo "${N3000_TRIPLEO_L3MH_ROUTE}" > "/etc/sysconfig/network-scripts/route-${requested_ifname}"

            /usr/sbin/ifup $requested_ifname
        done
    }

    function prepare_single() {
        echo "INFO: Preparing single interface init state for vRouter."

        local phy_id="$(echo ${config[physical_interface]} | awk -F'phy' '{ print $2; }')"
        echo "INFO: phy_id found: ${phy_id}"
        if [[ $phy_id == "0" || $phy_id == "1" ]]; then
            local phy_addr="$(lspci -d :0d58 -D | awk '{print $1}' | awk "NR == $(( phy_id + 1 ))")"
            local phy_ifname=$(realpath -e /sys/bus/pci/devices/${phy_addr}/net/* 2>/dev/null | awk -F/ '{print $NF}')
            local requested_ifname="${PHYSICAL_INTERFACE}"
            if [[ -z "${PHYSICAL_INTERFACE}" ]]; then
                requested_ifname="$(cat /var/run/vrouter/nic)"
            fi

            echo "INFO: phy_addr=$phy_addr, ifname found: $phy_ifname, requested ifname: $requested_ifname"
            ip link set "${phy_ifname}" down
            ip link set "${phy_ifname}" name "${requested_ifname}"

            set_network_info_for_device "${requested_ifname}" "${phy_addr}"

            ip link set "${requested_ifname}" up
        fi
    }

    function prepare_bonding() {
        echo "INFO: Preparing bonding init state for vRouter."

        local phy_addr="$(lspci -d :0d58 -D | awk '{print $1}' | awk "NR == 1")"
        local phy_ifname=$(realpath -e /sys/bus/pci/devices/${phy_addr}/net/* 2>/dev/null | awk -F/ '{print $NF}')
        local requested_ifname="${PHYSICAL_INTERFACE}"
        if [[ -z "${PHYSICAL_INTERFACE}" ]]; then
            requested_ifname="$(cat /var/run/vrouter/nic)"
        fi

        echo "INFO: phy_addr=$phy_addr, ifname found: $phy_ifname, requested ifname: $requested_ifname"
        ip link set "${phy_ifname}" down
        ip link set "${phy_ifname}" name "${requested_ifname}"

        set_network_info_for_device "${requested_ifname}" "${phy_addr}"

        ip link set "${requested_ifname}" up
    }

    local ifcfg_op=$1
    local n3000_conf=$2
    local env_file=$3
    local ifcfg_dir=$4

    local config_type=$(echo ${n3000_conf} | awk -F';' '{print $1}')
    local phy_addrs=$(lspci -d :0d58 -D | awk '{print $1}')

    echo "INFO: phy_addrs=$phy_addrs; n3000_conf=${n3000_conf}; ifcfg_dir=${ifcfg_dir}"

    local config
    eval $(get_config "${n3000_conf}")
    echo "INFO: Config:"
    declare -p config

    [[ "${ifcfg_op}" == "restore" ]] && restore_ifcfg "$ifcfg_dir"

    prepare_$config_type
}

function verify_vfs {
    local vfs_num=$1
    local -a pf_pci_addr_list=( $(lspci -nnD | awk '/1af4:1041/ { print  $1 }') )
    local pf0_addr=${pf_pci_addr_list[0]}
    local n3k_user_mode_config="unconfigured"
    local vfs_num_found

    if [[ "${N3000_PF0_DRIVER}" == "igb_uio" ]]; then
        [ -f /sys/bus/pci/devices/${pf0_addr}/max_vfs ] && vfs_num_found=$(cat /sys/bus/pci/devices/${pf0_addr}/max_vfs 2>/dev/null)
    else
        [ -f /sys/bus/pci/devices/${pf0_addr}/sriov_numvfs ] && vfs_num_found=$(cat /sys/bus/pci/devices/${pf0_addr}/sriov_numvfs 2>/dev/null)
    fi

    if [[ -n ${vfs_num_found} && ${vfs_num_found} != "0" ]] ; then
        if [[ "${vfs_num_found}" == "${vfs_num}" ]]; then
            n3k_user_mode_config="vfs-created"
        else
            n3k_user_mode_config="vfs-num-changed"
        fi
    fi

    echo -n "${n3k_user_mode_config}"
}

function verify_user_mode_config {
    local -a pf_pci_addr_list=( $(lspci -nnD | awk '/1af4:1041/ { print  $1 }') )
    local pf0_addr=${pf_pci_addr_list[0]}

    if [[ -z "${pf0_addr}" ]]; then
        echo -n "unconfigured"
        return
    fi

    local n3k_user_mode_config="$(verify_vfs 777)" # 777 is some invalid value

    echo -n "${n3k_user_mode_config}"
}

function switch_fpga_mode() {
    local requested_mode=$1
    local env_file=$2
    local found_mode="$(get_image_mode)"

    if [[ "${found_mode}" == "user" ]]; then
        local user_mode_config="$(verify_user_mode_config)"
        echo "INFO: user_mode_config found: ${user_mode_config}"

        if [[ "${user_mode_config}" != "unconfigured" ]]; then
            echo "ERROR: tried to switch modes when VFs are found"
            exit -1
        fi
    fi

    if [[ "${found_mode}" == "${requested_mode}" ]]; then
        # In theory boot page field shown is not deterministic - it can output an "user" value
        # although the card was never configured in the first place to the user mode.
        # However the deployment logic requires to only switch between modes -
        # that is: factory to known user mode state and unknown user mode to factory mode.
        # so there is no need for a logic for unknown user mode state to known user mode state
        echo "INFO: ${requested_mode} mode already present"
        return
    fi

    N3000_SWITCH_MODE="${requested_mode}" /etc/sysconfig/network-scripts/n3000/n3000-mode-manager.sh
}

function rebind_factory {
    local driver=$1
    for i in $(seq 1 2); do
        phy_addr=$( lspci -d :0d58 -D | awk '{print $1}' | awk "NR == $i" )

        override_driver "${phy_addr}" "${driver}"
    done
}

function setup_factory_mode {
    local env_file=$1

    switch_fpga_mode "factory" "${env_file}"

    rebind_factory "i40e"
}
