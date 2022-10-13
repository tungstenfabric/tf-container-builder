#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh

source /common.sh
source /agent-functions.sh

function configure_pf_and_vfs()
{
    local vfs_num=$1
    local pf_addr=$2

    local sub_vendor
    local sub_device
    local driver_in_use
    local current_pf_device_ifname
    local vf0_addr
    local -a vfs_pci_addr_list
    local current_vf_driver_path
    local current_vf_driver
    local current_vf_device_ifname
    local numvfs_fs="sriov_numvfs"
    if [[ ${PF0_DRIVER} == "igb_uio" ]]; then
        numvfs_fs="max_vfs"
    fi

    local sub_vendor=$(cat /sys/bus/pci/devices/${pf_addr}/subsystem_vendor)
    local sub_device=$(cat /sys/bus/pci/devices/${pf_addr}/subsystem_device)

    echo -e " PCI address: ${pf_addr} \n   - PCI subsystem_vendor: ${sub_vendor}\n   - PCI subsystem_device: ${sub_device}"

    if [[ "$sub_vendor" == "0x8086" && "$sub_device" == "0x15fe" ]]; then
        local current_pf_device_ifname=$(ls /sys/bus/pci/devices/${pf_addr}/virtio*/net 2>/dev/null)
        unbind_driver "$pf_addr"
        override_driver "$pf_addr" "$PF0_DRIVER"
        if [[ -n "${current_pf_device_ifname}" && -f "/etc/sysconfig/network-scripts/ifcfg-${current_pf_device_ifname}" ]]; then
            rm -f /etc/sysconfig/network-scripts/ifcfg-"${current_pf_device_ifname}"
        fi
        local driver_in_use=$(lspci -s ${pf_addr} -k | awk '/Kernel driver in use/ { print $5}')
        echo "Current driver in use: ${driver_in_use} target driver: ${PF0_DRIVER}"
        if [[ "$driver_in_use" == "$PF0_DRIVER" && -e "/sys/bus/pci/devices/${pf_addr}/${numvfs_fs}" ]]; then
            reconfigure_vfs ${vfs_num} "${pf_addr}"
        else
            echo "WARNING: Failed bind driver and start VFs for PF: ${pf_addr}"
        fi
    fi

    if [[ ${PF1_DRIVER} != "unbound" ]]; then
        local pf1_addr="${pf_addr/%.0}.1"

        unbind_driver "${pf1_addr}"
        override_driver "${pf1_addr}" "$PF1_DRIVER"
    fi
}

function reconfigure_vfs {
    local vfs_num=$1
    local pf_addr=$2
    local numvfs_fs="sriov_numvfs"
    if [[ ${PF0_DRIVER} == "igb_uio" ]]; then
        numvfs_fs="max_vfs"
    fi

    local current_num_vfs=$(cat "/sys/bus/pci/devices/${pf_addr}/${numvfs_fs}")
    if [[ "$current_num_vfs" -ne 0 ]]; then
        echo "INFO: Device $pf_addr setting current number of VF to 0"
        echo 0 > "/sys/bus/pci/devices/${pf_addr}/${numvfs_fs}"
        if [[ "$vfs_num" -eq 0 ]]; then
            return
        fi
    fi

    if [[ ${PF0_DRIVER} != "igb_uio" ]]; then
        echo 0 > "/sys/bus/pci/devices/${pf_addr}/sriov_drivers_autoprobe"
    fi

    echo "INFO: Device $pf_addr setting current number of VF to ${vfs_num}"
    if echo "${vfs_num}" > "/sys/bus/pci/devices/${pf_addr}/${numvfs_fs}" ; then
        echo "------ VFs configuration start ------"
        local vfs_pci_addr_list=( $(realpath -e /sys/bus/pci/devices/"${pf_addr}"/virtfn*/ | awk -F"/" '{print $NF}') )
        for vf_addr in ${vfs_pci_addr_list[@]};
        do
            local current_vf_driver_path=$(realpath -e /sys/bus/pci/devices/${vf_addr}/driver/ 2>/dev/null)
            local current_vf_driver=${current_vf_driver_path##*/}
            local current_vf_device_ifname=$(ls /sys/bus/pci/devices/${vf_addr}/virtio*/net 2>/dev/null)
            if [[ -e /sys/bus/pci/devices/${vf_addr}/driver &&  "$current_vf_driver" != "$VFs_DRIVER" ]]; then
                echo "INFO: VF ${vf_addr} configuration"
                unbind_driver "$vf_addr"
                override_and_clean_driver "$vf_addr" "$VFs_DRIVER"
                if [[ -n "${current_vf_device_ifname}" && -f "/etc/sysconfig/network-scripts/ifcfg-${current_vf_device_ifname}" ]]; then
                    rm -f /etc/sysconfig/network-scripts/ifcfg-"${current_vf_device_ifname}"
                fi
            elif [[ -e /sys/bus/pci/devices/${vf_addr}/driver &&  "$current_vf_driver" == "$VFs_DRIVER" ]]; then
                if [[ -n "${current_device_ifname}" && -f "/etc/sysconfig/network-scripts/ifcfg-${current_vf_device_ifname}" ]]; then
                    rm -f /etc/sysconfig/network-scripts/ifcfg-"${current_vf_device_ifname}"
                fi
            elif [[ ! -e /sys/bus/pci/devices/${vf_addr}/driver ]]; then
                override_and_clean_driver "$vf_addr" "$VFs_DRIVER"
            fi
        done
        if [[ ${PF0_DRIVER} != "igb_uio" ]]; then
            echo 1 > "/sys/bus/pci/devices/${pf_addr}/sriov_drivers_autoprobe"
        fi
        #echo "${vf0_addr}" > /sys/bus/pci/drivers_probe
        echo "------ VFs configuration finished ------"
    else
        if [[ ${PF0_DRIVER} != "igb_uio" ]]; then
            echo 1 > "/sys/bus/pci/devices/${pf_addr}/sriov_drivers_autoprobe"
        fi
    fi
}

function generate_dataplane_args(){
    function handle_single(){
        echo -n " --enable_n3k ${config[physical_interface]}"
    }

    function handle_bonding(){
        local bonding_mac=$(cat ${temp_data_dir}/mac0)

        echo -n ",lag=1 --vdev net_bonding0,mode=${config[bonding_mode]},slave=net_n3k0_phy0,slave=net_n3k0_phy1,mac=${bonding_mac},xmit_policy=${config[xmit_policy]},lacp_rate=${config[lacp_rate]},socket_id=0 --enable_n3k net_bonding0"
    }

    function handle_l3mh(){
        echo -n " --enable_n3k l3mh"
    }

    local n3000_conf=$1
    local config_type=$(echo ${n3000_conf} | awk -F';' '{print $1}')
    local config

    eval $(get_config "${n3000_conf}")

    handle_$config_type
}

function generate_mac_arg(){
    local macs="["
    local mac_list=$(ls "${temp_data_dir}" | awk '/mac/ { print $1 }')

    for mac_file in $mac_list; do
        local mac="$(cat ${temp_data_dir}/${mac_file})"

        macs+="${mac},"
    done

    macs="${macs%,}]"

    echo -n ",mac=$macs"
}


function prepare_n3000_args {
    local vfs_num=$1
    local pf1_driver=$2
    local args_dir=$3
    local pf0_addr=$4

    local insert_mode=${N3000_INSERT_MODE:-}
    local vfs_mqs_num=${N3000_VFs_QUEUE_NUM:-}
    local n3000_conf=${N3000_CONF:-}
    local vdpa_enabled=${N3000_VDPA_ENABLED:-}
    local vdpa_mapping_enabled=${N3000_VDPA_MAPPING_ENABLED:-}
    local drop_offload_enabled=${N3000_DROP_OFFLOAD_ENABLED:-}
    local aging_lcore_enabled=${N3000_AGING_LCORE_ENABLED:-}

    local pf1_addr=$(lspci -nnD | awk '/8086:15fe/ { print  $1 }')
    local mgmt_pf_addr="${pf0_addr}"
    if [[ ${pf1_driver} != "unbound" ]]; then
        mgmt_pf_addr="${pf1_addr}"
    fi

    local vf0_addr=$(realpath -e /sys/bus/pci/devices/${pf0_addr}/virtfn0 2>/dev/null | awk -F/ '{print $NF}')

    local args=""
    local vf_mqs=",mqs=[1,"
    local vf_list="["
    args+=" --whitelist pci:${vf0_addr}"

    local vfs_last_idx=$(expr ${vfs_num} - 1)
    for i in $(seq 1 ${vfs_last_idx}); do
        local vf_addr=$(realpath -e /sys/bus/pci/devices/${pf0_addr}/virtfn$i/ | awk -F/ '{print $NF}')
        if is_enabled ${vdpa_enabled}; then
            args+=" --whitelist pci:${vf_addr},vdpa=1"
        fi

        if [[ ${vfs_mqs_num} != "1" ]]; then
            vf_mqs+="${vfs_mqs_num},"
        fi

        vf_list+="$i,"
    done

    vf_mqs="${vf_mqs%,}]"
    vf_list="${vf_list%,}]"

    args+=" --whitelist pci:${mgmt_pf_addr},insert_type=${insert_mode}"
    if [[ ${vfs_mqs_num} != "1" ]]; then
        args+=${vf_mqs}
    fi

    args+=" --vdev net_n3k0,mgmt=${mgmt_pf_addr},pf=${vf0_addr},vfs=${vf_list}"
    args+=$(generate_mac_arg)
    args+=$(generate_dataplane_args "${n3000_conf}")

    if ! is_enabled ${drop_offload_enabled}; then
        args+=" --no_drop_offload"
    fi

    if is_enabled ${aging_lcore_enabled}; then
        args+=" --aging_lcore"
    fi

    if is_enabled ${vdpa_mapping_enabled}; then
        args+=" --force_vdpa_mapping"
    fi

    echo ${args} > ${args_dir}/args
}

function fetch_vrouter_info {
    function store_macs {
        local binding_data_dir="/var/run/vrouter"

        if [[ ! -f "${binding_data_dir}/nic" ]]; then
            echo "ERROR: nic file not found - mac info not stored"
            exit -1
        fi

        echo "INFO: Storing MACs to be passed onto DPDK"
        local phy_int_list=$(cat "${binding_data_dir}/nic")

        for phy_int in $phy_int_list; do
            local phy_int_mac=$(cat "$binding_data_dir/${phy_int}_mac")
            local pci_address=$(cat "$binding_data_dir/${phy_int}_pci")
            local pci_func=$(echo $pci_address | awk -F. '{print $(NF)}')
            local pfx_mac_file="${temp_data_dir}/mac${pci_func}"

            echo "Phy int pci: address: ${pci_address}, function: ${pci_func}, pfx_mac_file: ${pfx_mac_file}"
            echo "${phy_int_mac}" > ${pfx_mac_file}
        done

        for i in $(seq 0 1); do
            if [[ ! -f "${temp_data_dir}/mac$i" ]]; then
                echo "INFO: MAC for PHY$i set to 00:00:00:00:00:00 (PHY$i is not used)"
                echo "00:00:00:00:00:00" > "${temp_data_dir}/mac$i"
            fi
        done
    }

    store_macs
}


function setup_user_mode {
    local vfs_num=$1
    local user_mode_config=$2
    local ifcfg_dir=$3

    if [[ "${user_mode_config}" == "unconfigured" ]]; then
        switch_fpga_mode "user" "${env_file}"

        configure_pf_and_vfs "${vfs_num}" "$(get_pf0_address)"

        fetch_vrouter_info

        echo "INFO: Intel PAC N3000 configured"
    elif [[ "${user_mode_config}" == "vfs-num-changed" ]]; then
        echo "INFO: Incorrect number of VFs created, recreating with correct amount"

        reconfigure_vfs "${vfs_num}" "$(get_pf0_address)"

        echo "INFO: VFs recreated"
    elif [[ "${user_mode_config}" == "vfs-created" ]]; then
        echo "INFO: VFs already created"
    else
        echo "ERROR: Config verification went wrong"
        exit -1
    fi
}

function enable_user_mode() {
    echo "INFO: Checking and modprobing modules"

    check_module 'intel-fpga-pci'
    check_modules $PF0_DRIVER $PF1_DRIVER $VFs_DRIVER

    echo "INFO: Verifying config"
    local user_mode_config="$(verify_vfs ${VFs_NUM})"

    echo "INFO: Setup of N3000 user image mode"
    setup_user_mode "${VFs_NUM}" "${user_mode_config}" "${ifcfg_dir}"

    echo "INFO: Restoring ifcfg"
    restore_ifcfg "$ifcfg_dir"

    echo "INFO: N3000-vRouter CLI argument preparation"
    prepare_n3000_args ${VFs_NUM} ${PF1_DRIVER} "${temp_data_dir}" "$(get_pf0_address)"

    echo "INFO: N3000-vRouter initialization done"
}

function disable_user_mode() {
    local pf0_addr="$(get_pf0_address)"

    echo "INFO: disabling VFs"
    reconfigure_vfs 0 "${pf0_addr}"

    echo "INFO: Switching to factory mode"
    setup_factory_mode "${env_file}"
}

LANG=en_US.UTF-8

command=$1
temp_data_dir=$2
ifcfg_dir=$3
env_file=$4

if [[ ! -d "${temp_data_dir}" ]]; then
    echo "ERROR: temp_data_dir does not exist"
    exit -1
fi

if [[ ! -d "${ifcfg_dir}" ]]; then
    echo "ERROR: ifcfg_dir does not exist"
    exit -1
fi

VFs_NUM=${N3000_VFs_NUM:-}
VFs_DRIVER=vfio-pci
PF0_DRIVER=${N3000_PF0_DRIVER:-"pci-pf-stub"}
PF1_DRIVER="unbound"
if [[ ${PF0_DRIVER} == "pci-pf-stub" ]]; then
    PF1_DRIVER="uio_pci_generic"
fi

${command}_user_mode
