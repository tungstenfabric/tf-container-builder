#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-driver-mgmt.sh

source /agent-functions.sh

function setup_n3000_env {
    mkdir -p /var/lib/contrail/vrouter/n3000 || true

    for i in {1..300} ; do
        echo "Waiting for n3000-init container to finish...($i/300)"
        [[ -f /var/lib/contrail/vrouter/n3000/rsu ]] && break;
        if (( i == 300 )) ; then
            echo "Time for n3000-init container to finish exceeded."
            exit -1
        fi
        sleep 1
    done
}

function get_pf0_address() {
    declare -a pf_pci_addr_list=( $(lspci -nnD | awk '/1af4:1041/ { print  $1 }') )

    for pf_addr in ${pf_pci_addr_list[@]}; do
        sub_vendor=$(cat /sys/bus/pci/devices/${pf_addr}/subsystem_vendor)
        sub_device=$(cat /sys/bus/pci/devices/${pf_addr}/subsystem_device)
        if [[ "$sub_vendor" == "0x8086" && "$sub_device" == "0x15fe" ]]; then
            PF0_ADDR=${pf_addr}
            return
        fi
    done
}

function setup_ifcfg {
    if [[ -f /etc/sysconfig/network-scripts/ifcfg-${N3000_CUSTOM_VF0_NAME} ]]; then
        return
    fi

    get_pf0_address
    local pf_addr=${PF0_ADDR}

    if [[ -n "${BIND_INT}" ]]; then
        if [[ -f /sys/bus/pci/devices/${pf_addr}/virtio*/net/* ]]; then
            local pf0_ifname=$(realpath -e /sys/bus/pci/devices/${pf_addr}/virtio*/net/* 2>/dev/null | awk -F/ '{print $NF}')
            if [[ -f /etc/sysconfig/network-scripts/ifcfg-${pf0_ifname} ]]; then
                cp /etc/sysconfig/network-scripts/ifcfg-${pf0_ifname} /etc/sysconfig/network-scripts/ifcfg-${N3000_CUSTOM_VF0_NAME}
            fi
        fi
    fi
}

function configure_pf_and_vfs()
{
    local vfs_num=$1

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

    local pf_addr=${PF0_ADDR}
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
            reconfigure_vfs ${vfs_num}
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
    local pf_addr=${PF0_ADDR}
    local numvfs_fs="sriov_numvfs"
    if [[ ${PF0_DRIVER} == "igb_uio" ]]; then
        numvfs_fs="max_vfs"
    fi

    local current_num_vfs=$(cat "/sys/bus/pci/devices/${pf_addr}/${numvfs_fs}")
    if [[ "$current_num_vfs" -ne 0 ]]; then
        echo "INFO: Device $pf_addr setting current number of VF to 0"
        echo 0 > "/sys/bus/pci/devices/${pf_addr}/${numvfs_fs}"
    fi

    if [[ ${PF0_DRIVER} != "igb_uio" ]]; then
        echo 0 > "/sys/bus/pci/devices/${pf_addr}/sriov_drivers_autoprobe"
    fi

    echo "INFO: Device $pf_addr setting current number of VF to ${vfs_num}"
    if echo "${vfs_num}" > "/sys/bus/pci/devices/${pf_addr}/${numvfs_fs}" ; then
        echo "------ VFs configuration start ------"
        local vf0_addr=$(realpath -e /sys/bus/pci/devices/${pf_addr}/virtfn0 2>/dev/null | awk -F"/" '{print $NF}')
        local vfs_pci_addr_list=( $(realpath -e /sys/bus/pci/devices/"${pf_addr}"/virtfn*/ | grep -v "${vf0_addr}" | awk -F"/" '{print $NF}') )
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
        echo "${vf0_addr}" > /sys/bus/pci/drivers_probe
        echo "------ VFs configuration finished ------"
    else
        if [[ ${PF0_DRIVER} != "igb_uio" ]]; then
            echo 1 > "/sys/bus/pci/devices/${pf_addr}/sriov_drivers_autoprobe"
        fi
    fi
}

function prepare_n3000_args {
    local vfs_num=$1
    local pf1_driver=$2
    local args_dir=$3

    local insert_mode=${N3000_INSERT_MODE:-}
    local vfs_mqs_num=${N3000_VFs_QUEUE_NUM:-}
    local bonding_mode=${N3000_BONDING_MODE:-}
    local vdpa_enabled=${N3000_VDPA_ENABLED:-}
    local vdpa_mapping_enabled=${N3000_VDPA_MAPPING_ENABLED:-}
    local drop_offload_enabled=${N3000_DROP_OFFLOAD_ENABLED:-}
    local aging_lcore_enabled=${N3000_AGING_LCORE_ENABLED:-}

    get_pf0_address

    local pf1_addr=$(lspci -nnD | awk '/8086:15fe/ { print  $1 }')

    local mgmt_pf_addr=${PF0_ADDR}
    if [[ ${pf1_driver} != "unbound" ]]; then
        mgmt_pf_addr=${pf1_addr}
    fi

    local vf0_addr=$(realpath -e /sys/bus/pci/devices/${PF0_ADDR}/virtfn0 2>/dev/null | awk -F/ '{print $NF}')
    local vf0_mac=$(cat /sys/bus/pci/devices/${vf0_addr}/virtio0/net/*/address 2>/dev/null)

    local args=""
    local vf_mqs=",mqs=[1,"
    local vf_list="["
    local vr_phy_dev="net_n3k0_phy0"
    args+=" --whitelist pci:${vf0_addr}"

    vfs_last_idx=$(expr ${vfs_num} - 1)
    for i in $(seq 1 ${vfs_last_idx}); do
        local vf_addr=$(realpath -e /sys/bus/pci/devices/${PF0_ADDR}/virtfn$i/ | awk -F/ '{print $NF}')
        if [[ "${vdpa_enabled}" == "true" ]]; then
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

    if [[ "${bonding_mode}" != "nobonding" ]]; then
        vr_phy_dev="net_bonding0"
        local policy=$(convert_bond_policy $BOND_POLICY)
        args+=",lag=1 --vdev net_bonding0,mode=${bonding_mode},slave=net_n3k0_phy0,slave=net_n3k0_phy1,mac=${vf0_mac},xmit_policy=${policy:-"l34"}"
        if [[ -n "${LACP_RATE}" ]]; then
            args+=",lacp_rate=${LACP_RATE}"
        fi
    fi

    args+=" --enable_n3k ${vr_phy_dev}"

    if [[ "${drop_offload_enabled}" == "false" ]]; then
        args+=" --no_drop_offload"
    fi

    if [[ "${aging_lcore_enabled}" == "true" ]]; then
        args+=" --aging_lcore"
    fi

    if [[ "${vdpa_mapping_enabled}" == "true" ]]; then
        args+=" --force_vdpa_mapping"
    fi

    echo ${args} > ${args_dir}/args
}

function verify_config {
    local vfs_num=$1
    local -a pf_pci_addr_list=( $(lspci -nnD | awk '/1af4:1041/ { print  $1 }') )
    local pf0_addr=${pf_pci_addr_list[0]}
    local vfs_num_found="0"

    N3K_CONFIG="unconfigured"

    if [[ "${PF0_DRIVER}" == "igb_uio" ]]; then
        [ -f /sys/bus/pci/devices/${pf0_addr}/max_vfs ] && vfs_num_found=$(cat /sys/bus/pci/devices/${pf0_addr}/max_vfs 2>/dev/null)
    else
        [ -f /sys/bus/pci/devices/${pf0_addr}/sriov_numvfs ] && vfs_num_found=$(cat /sys/bus/pci/devices/${pf0_addr}/sriov_numvfs 2>/dev/null)
    fi

    if [[ -n ${vfs_num_found} && ${vfs_num_found} != "0" ]] ; then
        if [[ "${vfs_num_found}" == "${vfs_num}" ]]; then
            N3K_CONFIG="vfs-created"
        else
            N3K_CONFIG="vfs-num-changed"
        fi
    fi
}

function configure_n3000 {
    local vfs_num=$1
    local fpga_pci_addr=$(lspci -nnD | awk '/8086:0b30/ { print $1 }')
    local fpga_pci_addr_short=$(lspci -nnD | awk '/8086:0b30/ { print substr($1, 6,2) }')

    echo "FME FPGA PCI address found: ${fpga_pci_addr}"

    if [[ ${N3K_CONFIG} == "unconfigured" ]]; then
        echo -e "INFO: Starting Intel PAC N3000 configuration \nFPGA PCI address: ${fpga_pci_addr}"

        unbind_n3000_xxv710

        sleep 0.5
        PYTHONPATH=/var/lib/contrail/vrouter/n3000/site_packages /var/lib/contrail/vrouter/n3000/fecmode -B ${fpga_pci_addr_short} --rsu no

        sleep 0.5
        fpga_pci_addr=$(lspci -nnD | awk '/8086:0b30/ { print $1 }')
        unbind_n3000_xxv710

        sleep 0.5
        PYTHONPATH=/var/lib/contrail/vrouter/n3000/site_packages /var/lib/contrail/vrouter/n3000/rsu bmcimg "${fpga_pci_addr}"

        sleep 0.5
        unbind_n3000_xxv710

        get_pf0_address
        configure_pf_and_vfs ${VFs_NUM}

        echo "INFO: Intel PAC N3000 configured"
    elif [[ ${N3K_CONFIG} == "vfs-num-changed" ]]; then
        echo "INFO: Incorrect number of VFs created, recreating with correct amount"

        get_pf0_address
        reconfigure_vfs ${VFs_NUM}

        echo "INFO: VFs recreated"
    elif [[ ${N3K_CONFIG} == "vfs-created" ]]; then
        echo "INFO: VFs already created"

        get_pf0_address
    else
        echo "ERROR: Config verification went wrong"
    fi

    local vf0_addr=$(realpath -e /sys/bus/pci/devices/${PF0_ADDR}/virtfn0 2>/dev/null | awk -F/ '{print $NF}')
    local current_vf0_driver_path=$(realpath -e /sys/bus/pci/devices/${vf0_addr}/driver/ 2>/dev/null)
    local current_vf0_driver=${current_vf0_driver_path##*/}

    if [[ ${current_vf0_driver} != "virtio-pci" ]]; then
        echo "INFO: VF0 not bound to virtio-pci - rebinding"
        unbind_driver "${vf0_addr}"
        override_and_clean_driver "${vf0_addr}" "virtio-pci"
        echo "INFO: VF0 rebound to kernel"
    fi
}

function set_vf0_name {
    local vf0_addr=$(realpath -e /sys/bus/pci/devices/${PF0_ADDR}/virtfn0 2>/dev/null | awk -F/ '{print $NF}')
    local vf0_ifname=$(realpath -e /sys/bus/pci/devices/${vf0_addr}/virtio*/net/* 2>/dev/null | awk -F/ '{print $NF}')

    ip link set dev ${vf0_ifname} down

    if [[ -n "${MACADDR}" ]]; then
        ip link set dev ${vf0_ifname} address ${MACADDR} && \
            echo "Set VF0 mac to: ${MACADDR}"
    fi

    if [[ -n "${N3000_CUSTOM_VF0_NAME}" ]] ; then
        ip link set dev ${vf0_ifname} name ${N3000_CUSTOM_VF0_NAME} && \
            echo "Set VF0 ifname to: ${N3000_CUSTOM_VF0_NAME}"
    fi
}

function save_vf0_ifname {
    local args_dir=$1

    local vf0_addr=$(realpath -e /sys/bus/pci/devices/${PF0_ADDR}/virtfn0 2>/dev/null | awk -F/ '{print $NF}')
    local vf0_ifname=$(realpath -e /sys/bus/pci/devices/${vf0_addr}/virtio0/net/* 2>/dev/null | awk -F/ '{print $NF}')

    echo ${vf0_ifname} > ${args_dir}/vf0_ifname
    echo ${vf0_addr} > ${args_dir}/vf0_pci
}

args_dir=$1

LANG=en_US.UTF-8
VFs_NUM=${N3000_VFs_NUM:-}
VFs_DRIVER=vfio-pci
PF0_DRIVER=${N3000_PF0_DRIVER:-"pci-pf-stub"}
PF1_DRIVER="unbound"
if [[ ${PF0_DRIVER} == "pci-pf-stub" ]]; then
    PF1_DRIVER="uio_pci_generic"
fi

echo "INFO: Setupping necessary n3000 configuration tools"
setup_n3000_env

echo "INFO: Checking and modprobing modules"

if ! modprobe -i intel-fpga-pci ; then
    modprobe intel-fpga-pci
    echo "INFO: Modprobing intel-fpga-pci"
fi

check_modules $PF0_DRIVER $PF1_DRIVER $VFs_DRIVER

echo "INFO: Verifying config"
verify_config ${VFs_NUM}

echo "INFO: Ifcfg management"
setup_ifcfg

echo "INFO: Configuring N3000"
configure_n3000 ${VFs_NUM}

echo "INFO: Setting N3000 custom VF0 ifname if required: ${N3000_CUSTOM_VF0_NAME}"
set_vf0_name

echo "INFO: Storing N3000 VF0 ifname"
save_vf0_ifname ${args_dir}

echo "INFO: N3000-vRouter CLI argument preparation"
prepare_n3000_args ${VFs_NUM} ${PF1_DRIVER} ${args_dir}

echo "INFO: N3000-vRouter initialization done"
