#!/bin/bash

source /common.sh
source /agent-functions.sh

RESULTFILE=${RESULTFILE:-'/var/run/hostdata'}

declare -A config

vrouter_cidr=$(get_cidr_for_nic 'vhost0')

if [[ -z "$vrouter_cidr" ]] ; then
    echo "ERROR: vhost0 interface is down or has no assigned IP"
    exit 1
fi
vrouter_ip=${vrouter_cidr%/*}
agent_name=${VROUTER_HOSTNAME:-"$(resolve_hostname_by_ip $vrouter_ip)"}
[ -z "$agent_name" ] && agent_name="$(get_default_hostname)"
vrouter_gateway=$(get_default_vrouter_gateway)

config["vrouter_cidr"]=$vrouter_cidr
config["vrouter_ip"]=$vrouter_ip
config["vrouter_gateway"]=$vrouter_gateway
config["agent_name"]=$agent_name

# Google has point to point DHCP address to the VM, but we need to initialize
# with the network address mask. This is needed for proper forwarding of pkts
# at the vrouter interface
gcp=$(cat /sys/devices/virtual/dmi/id/chassis_vendor)
if [ "$gcp" == "Google" ]; then
    intfs=$(curl -s http://metadata.google.internal/computeMetadata/v1beta1/instance/network-interfaces/)
    for intf in $intfs ; do
        if [[ $phys_int_mac == "$(curl -s http://metadata.google.internal/computeMetadata/v1beta1/instance/network-interfaces/${intf}/mac)" ]]; then
            mask=$(curl -s http://metadata.google.internal/computeMetadata/v1beta1/instance/network-interfaces/${intf}/subnetmask)
            vrouter_cidr=$vrouter_ip/$(mask2cidr $mask)
            config["cidr"]=$vrouter_cidr
        fi
    done
fi

if ! is_dpdk ; then
    IFS=' ' read -r phys_int phys_int_mac <<< $(get_physical_nic_and_mac)
    pci_address=$(get_pci_address_for_nic $phys_int)
else
    binding_data_dir='/var/run/vrouter'
    phys_int=`cat $binding_data_dir/nic`
    phys_int_mac=`cat $binding_data_dir/${phys_int}_mac`
    pci_address=`cat $binding_data_dir/${phys_int}_pci`
fi

config["pci_address"]=$pci_address
config["phys_int"]=$phys_int
config["phys_int_mac"]=$phys_int_mac

control_network_ip=$(get_ip_for_vrouter_from_control)
config["control_network_ip"]=$control_network_ip

if [ "$CLOUD_ORCHESTRATOR" == "vcenter" ] && ! is_tsn; then
    HYPERVISOR_TYPE=${HYPERVISOR_TYPE:-'vmware'}
    vmware_phys_int=$(get_vmware_physical_iface)
    disable_chksum_offload $phys_int
    disable_lro_offload $vmware_phys_int
    vmware_mode = vcenter
    config["vmware_phys_int"]=$vmware_phys_int
    config["vmware_mode"]=$vmware_mode
fi

if (( HUGE_PAGES_1GB > 0 )) ; then
    hp_dir=${HUGE_PAGES_1GB_DIR:-${HUGE_PAGES_DIR}}
    ensure_hugepages ${hp_dir}
    allocated_pages_1GB=$(cat /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages)
    echo "INFO: Requested HP1GB $HUGE_PAGES_1GB available $allocated_pages_1GB"
    if  (( HUGE_PAGES_1GB > allocated_pages_1GB )) ; then
        echo "INFO: Requested HP1GB  $HUGE_PAGES_1GB more then available $allocated_pages_1GB.. try to allocate"
        echo $HUGE_PAGES_1GB > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
    fi
    huge_page_1G="${hp_dir}/bridge ${hp_dir}/flow"
    config["huge_page_1G"]=$huge_page_1G
elif (( HUGE_PAGES_2MB > 0 )) ; then
    hp_dir=${HUGE_PAGES_2MB_DIR:-${HUGE_PAGES_DIR}}
    ensure_hugepages ${hp_dir}
    allocated_pages_2MB=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
    echo "INFO: Requested HP2MB  $HUGE_PAGES_2MB available $allocated_pages_2MB"
    if  (( HUGE_PAGES_2MB > allocated_pages_2MB )) ; then
        echo "INFO: Requested HP2MB  $HUGE_PAGES_2MB more then available $allocated_pages_2MB.. try to allocate"
        echo $HUGE_PAGES_2MB > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
    fi
    huge_page_2M=${hp_dir}/bridge ${hp_dir}/flow
    config["huge_page_2M"]=$huge_page_2M
fi

if [[ -z "$K8S_TOKEN" ]]; then
    k8s_token_file=${K8S_TOKEN_FILE:-'/var/run/secrets/kubernetes.io/serviceaccount/token'}
    if [[ -f "$k8s_token_file" ]]; then
        K8S_TOKEN=`cat "$k8s_token_file"`
    fi
fi
config["k8s_token"]=$K8S_TOKEN

if [ -f $RESULTFILE ]; then
  rm -f $RESULTFILE
fi
for key in ${!config[@]}; do
  echo "$key=${config[$key]}" >> $RESULTFILE
done
