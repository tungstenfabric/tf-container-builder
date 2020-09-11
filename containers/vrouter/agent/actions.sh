#!/bin/bash
# This file contains vrouter-agent container related logic. Can be called from entrypoint.sh
# or directly.
# To run these functions, source agent_functions.sh and common.sh before

parameters_file='/parameters.sh'

function prepare_agent_config_vars {
    echo "INFO: Start prepare_agent_config_vars"
    # TODO: avoid duplication of reading parameters with init_vhost0
    local PHYS_INT_MAC PHYS_INT is_dpdk PCI_ADDRESS
    if ! is_dpdk ; then
        IFS=' ' read -r PHYS_INT PHYS_INT_MAC <<< $(get_physical_nic_and_mac)
        PCI_ADDRESS=$(get_pci_address_for_nic $PHYS_INT)
    else
        binding_data_dir='/var/run/vrouter'
        PHYS_INT=`cat $binding_data_dir/nic`
        PHYS_INT_MAC=`cat $binding_data_dir/${PHYS_INT}_mac`
        PCI_ADDRESS=`cat $binding_data_dir/${PHYS_INT}_pci`
    fi

    if [ "$CLOUD_ORCHESTRATOR" == "kubernetes" ] && [ ! -z $VROUTER_GATEWAY ]; then
        # dont need k8s_pod_cidr_route if default gateway is vhost0
        add_k8s_pod_cidr_route
    fi

    VROUTER_GATEWAY=${VROUTER_GATEWAY:-`get_default_vrouter_gateway`}
    local VROUTER_CIDR=$(get_cidr_for_nic 'vhost0')
    echo "INFO: Physical interface: $PHYS_INT, mac=$PHYS_INT_MAC, pci=$PCI_ADDRESS"
    echo "INFO: vhost0 cidr $VROUTER_CIDR, gateway $VROUTER_GATEWAY"

    if [ "$CLOUD_ORCHESTRATOR" == "vcenter" ] && ! is_tsn; then
        HYPERVISOR_TYPE=${HYPERVISOR_TYPE:-'vmware'}
        local VMWARE_PHYS_INT=$(get_vmware_physical_iface)
        disable_chksum_offload $PHYS_INT
        disable_lro_offload $VMWARE_PHYS_INT
    else
        HYPERVISOR_TYPE=${HYPERVISOR_TYPE:-'kvm'}
    fi

    if [[ -z "$VROUTER_CIDR" ]] ; then
        echo "ERROR: vhost0 interface is down or has no assigned IP"
        exit 1
    fi
    local vrouter_ip=${VROUTER_CIDR%/*}
    local AGENT_NAME=${VROUTER_HOSTNAME:-"$(resolve_hostname_by_ip $vrouter_ip)"}
    [ -z "$AGENT_NAME" ] && AGENT_NAME="$(get_default_hostname)"

    # Google has point to point DHCP address to the VM, but we need to initialize
    # with the network address mask. This is needed for proper forwarding of pkts
    # at the vrouter interface
    local gcp=$(cat /sys/devices/virtual/dmi/id/chassis_vendor)
    if [ "$gcp" == "Google" ]; then
        local interfaces=$(curl -s http://metadata.google.internal/computeMetadata/v1beta1/instance/network-interfaces/)
        local intf mask
        for intf in $interfaces ; do
            if [[ $PHYS_INT_MAC == "$(curl -s http://metadata.google.internal/computeMetadata/v1beta1/instance/network-interfaces/${intf}/mac)" ]]; then
                mask=$(curl -s http://metadata.google.internal/computeMetadata/v1beta1/instance/network-interfaces/${intf}/subnetmask)
                VROUTER_CIDR=$vrouter_ip/$(mask2cidr $mask)
            fi
        done
    fi

    local IS_VLAN_ENABLED IS_ENCRYPTION_SUPPORTED_FLAG
    if is_vlan $PHYS_INT; then
        IS_VLAN_ENABLED="true"
    else
        IS_VLAN_ENABLED="false"
    fi

    if is_encryption_supported ; then
        IS_ENCRYPTION_SUPPORTED_FLAG="true"
    else
        IS_ENCRYPTION_SUPPORTED_FLAG="false"
    fi

    local hugepages_option=""
    local HUGEPAGES_DIR allocated_pages_1GB allocated_pages_2MB
    if (( HUGE_PAGES_1GB > 0 )) ; then
        HUGEPAGES_DIR=${HUGE_PAGES_1GB_DIR:-${HUGE_PAGES_DIR}}
        ensure_hugepages ${HUGEPAGES_DIR}
        allocated_pages_1GB=$(cat /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages)
        echo "INFO: Requested HP1GB $HUGE_PAGES_1GB available $allocated_pages_1GB"
        if  (( HUGE_PAGES_1GB > allocated_pages_1GB )) ; then
            echo "INFO: Requested HP1GB  $HUGE_PAGES_1GB more then available $allocated_pages_1GB.. try to allocate"
            echo $HUGE_PAGES_1GB > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
        fi
EOM
    elif (( HUGE_PAGES_2MB > 0 )) ; then
        HUGEPAGES_DIR=${HUGE_PAGES_2MB_DIR:-${HUGE_PAGES_DIR}}
        ensure_hugepages ${HUGEPAGES_DIR}
        allocated_pages_2MB=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
        echo "INFO: Requested HP2MB  $HUGE_PAGES_2MB available $allocated_pages_2MB"
        if  (( HUGE_PAGES_2MB > allocated_pages_2MB )) ; then
            echo "INFO: Requested HP2MB  $HUGE_PAGES_2MB more then available $allocated_pages_2MB.. try to allocate"
            echo $HUGE_PAGES_2MB > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
        fi
    fi

    local INTROSPECT_IP='0.0.0.0'
    if ! is_enabled ${INTROSPECT_LISTEN_ALL} ; then
        INTROSPECT_IP=$vrouter_ip
    fi

    local COMPUTE_NODE_ADDRESS=${VROUTER_COMPUTE_NODE_ADDRESS:-$vrouter_ip}

    local XMPP_SERVERS_LIST=${XMPP_SERVERS:-`get_server_list CONTROL ":$XMPP_SERVER_PORT "`}
    local CONTROL_NETWORK_IP=$(get_ip_for_vrouter_from_control)
    local DNS_SERVERS_LIST=${DNS_SERVERS:-`get_server_list DNS ":$DNS_SERVER_PORT "`}
    local XMPP_SSL_IS_ENABLED
    if is_enabled ${XMPP_SSL_ENABLE} ; then
        XMPP_SSL_IS_ENABLED="true"
    else
        XMPP_SSL_IS_ENABLED="false"
    fi

    local INTROSPECT_SSL_IS_ENABLED
    if is_enabled ${INTROSPECT_SSL_ENABLE} ; then
        INTROSPECT_SSL_IS_ENABLED="true"
    else
        INTROSPECT_SSL_IS_ENABLED="false"
    fi

    local result_params=""
    while read line; do
        IFS='=' read -ra key <<< "$line"
        if [[ -n "${key[0]}" ]]; then
            read -r -d '' result_params<< EOM || true
${result_params}
${key[0]}=${!key[0]}

EOM
        fi
    done <$parameters_file
    echo "$result_params" > $parameters_file
}

function create_agent_config() {
    echo "INFO: Preparing /etc/contrail/contrail-vrouter-agent.conf"

    if ! [[  -f  $parameters_file ]]; then
      echo "ERROR: Can\'t find params file $parameters_file"
      exit 1
    fi

    source $parameters_file

    if [ "$CLOUD_ORCHESTRATOR" == "vcenter" ] && ! [[ -n "$TSN_AGENT_MODE" ]]; then
        read -r -d '' vmware_options << EOM || true
vmware_physical_interface = $VMWARE_PHYS_INT
vmware_mode = vcenter
EOM
    fi

    agent_mode_options="physical_interface_mac = $PHYS_INT_MAC"
    if [[ "$AGENT_MODE" == 'dpdk' ]]; then
        read -r -d '' agent_mode_options << EOM || true
platform=${AGENT_MODE}
physical_interface_mac=$PHYS_INT_MAC
physical_interface_address=$PCI_ADDRESS
physical_uio_driver=${DPDK_UIO_DRIVER}
EOM
    fi

    tsn_agent_mode=""
    if [[ -n "$TSN_AGENT_MODE" ]] ; then
        read -r -d '' tsn_agent_mode << EOM || true
agent_mode = ${TSN_AGENT_MODE}
EOM
    fi

    vrouter_gateway_opts=''
    if [[ -n "$VROUTER_GATEWAY" ]] ; then
        vrouter_gateway_opts="gateway=$VROUTER_GATEWAY"
    fi

    subcluster_option=""
    if [[ -n ${SUBCLUSTER} ]]; then
    read -r -d '' subcluster_option << EOM || true
subcluster_name=${SUBCLUSTER}
EOM
    fi

    read -r -d '' tsn_server_list << EOM || true
tsn_servers = `echo ${TSN_NODES} | tr ',' ' '`
EOM

    priority_group_option=""
    if [[ -n "${PRIORITY_ID}" ]] && [[ "$AGENT_MODE" != 'dpdk' ]]; then
        priority_group_option="[QOS-NIANTIC]"
        IFS=',' read -ra priority_id_list <<< "${PRIORITY_ID}"
        IFS=',' read -ra priority_bandwidth_list <<< "${PRIORITY_BANDWIDTH}"
        IFS=',' read -ra priority_scheduling_list <<< "${PRIORITY_SCHEDULING}"
        for index in ${!priority_id_list[@]}; do
            read -r -d '' qos_niantic << EOM
[PG-${priority_id_list[${index}]}]
scheduling=${priority_scheduling_list[${index}]}
bandwidth=${priority_bandwidth_list[${index}]}

EOM
            priority_group_option+=$'\n'"${qos_niantic}"
        done
        if [[ $IS_VLAN_ENABLED == "true" ]]; then
            echo "ERROR: qos scheduling not supported for vlan interface skipping ."
            priority_group_option=""
        fi
    fi

    qos_queueing_option=""
    if [[ -n "${QOS_QUEUE_ID}" ]] && [[ "$AGENT_MODE" != 'dpdk' ]]; then
        qos_queueing_option="[QOS]"$'\n'"priority_tagging=${PRIORITY_TAGGING}"
        IFS=',' read -ra qos_queue_id <<< "${QOS_QUEUE_ID}"
        IFS=';' read -ra qos_logical_queue <<< "${QOS_LOGICAL_QUEUES}"
        for index in ${!qos_queue_id[@]}; do
            if [[ ${index} -ge $((${#qos_queue_id[@]} - 1)) ]]; then
                break
            fi
            read -r -d '' qos_config << EOM
[QUEUE-${qos_queue_id[${index}]}]
logical_queue=${qos_logical_queue[${index}]}

EOM
            qos_queueing_option+=$'\n'"${qos_config}"
        done
        qos_def=""
        if is_enabled ${QOS_DEF_HW_QUEUE} ; then
            qos_def="default_hw_queue=true"
        fi

        if [[ ${#qos_queue_id[@]} -ne ${#qos_logical_queue[@]} ]]; then
            qos_logical_queue+=('[]')
        fi

        read -r -d '' qos_config << EOM
[QUEUE-${qos_queue_id[-1]}]
logical_queue=${qos_logical_queue[-1]}
${qos_def}

EOM
        qos_queueing_option+=$'\n'"${qos_config}"
    fi

    metadata_ssl_conf=''
    if is_enabled "$METADATA_SSL_ENABLE" ; then
        read -r -d '' metadata_ssl_conf << EOM
metadata_use_ssl=${METADATA_SSL_ENABLE}
metadata_client_cert=${METADATA_SSL_CERTFILE}
metadata_client_key=${METADATA_SSL_KEYFILE}
metadata_ca_cert=${METADATA_SSL_CA_CERTFILE}
EOM
        if [[ -n "$METADATA_SSL_CERT_TYPE" ]] ; then
            metadata_ssl_conf+=$'\n'"${METADATA_SSL_CERT_TYPE}"
        fi
    fi

    crypt_interface_option=""
    if [[ "$IS_ENCRYPTION_SUPPORTED_FLAG" == "true" ]]; then
        read -r -d '' crypt_interface_option << EOM || true
[CRYPT]
crypt_interface=$VROUTER_CRYPT_INTERFACE
EOM
    fi

    hugepages_option=""
    if (( HUGE_PAGES_1GB > 0 )) ; then
    read -r -d '' hugepages_option << EOM || true
[RESTART]
huge_page_1G=${HUGEPAGES_DIR}/bridge ${HUGEPAGES_DIR}/flow
EOM
    elif (( HUGE_PAGES_2MB > 0 )) ; then
    read -r -d '' hugepages_option << EOM || true
[RESTART]
huge_page_2M=${HUGEPAGES_DIR}/bridge ${HUGEPAGES_DIR}/flow
EOM
    fi

    if [[ "$XMPP_SSL_IS_ENABLED" == "true" ]] ; then
        read -r -d '' xmpp_certs_config << EOM || true
xmpp_server_cert=${XMPP_SERVER_CERTFILE}
xmpp_server_key=${XMPP_SERVER_KEYFILE}
xmpp_ca_cert=${XMPP_SERVER_CA_CERTFILE}
EOM
    else
        xmpp_certs_config=''
    fi

    if [[ "$INTROSPECT_SSL_IS_ENABLED" == 'true' ]]; then
        read -r -d '' sandesh_client_config << EOM || true
[SANDESH]
introspect_ssl_enable=${INTROSPECT_SSL_ENABLE}
introspect_ssl_insecure=${INTROSPECT_SSL_INSECURE}
sandesh_ssl_enable=${SANDESH_SSL_ENABLE}
sandesh_keyfile=${SANDESH_KEYFILE}
sandesh_certfile=${SANDESH_CERTFILE}
sandesh_ca_cert=${SANDESH_CA_CERTFILE}
EOM
    else
        read -r -d '' sandesh_client_config << EOM || true
[SANDESH]
introspect_ssl_enable=${INTROSPECT_SSL_ENABLE}
sandesh_ssl_enable=${SANDESH_SSL_ENABLE}
EOM
    fi

    if [[ -n "$STATS_COLLECTOR_DESTINATION_PATH" ]]; then
        read -r -d '' collector_stats_config << EOM || true
[STATS]
stats_collector=${STATS_COLLECTOR_DESTINATION_PATH}
EOM
    else
        collector_stats_config=''
    fi

    upgrade_old_logs "vrouter-agent"
    mkdir -p /etc/contrail
    cat << EOM > /etc/contrail/contrail-vrouter-agent.conf
[CONTROL-NODE]
servers=$XMPP_SERVERS_LIST
$subcluster_option

[DEFAULT]
http_server_ip=$INTROSPECT_IP
collectors=$COLLECTOR_SERVERS
log_file=$CONTAINER_LOG_DIR/contrail-vrouter-agent.log
log_level=$LOG_LEVEL
log_local=$LOG_LOCAL

hostname=${AGENT_NAME}
agent_name=${AGENT_NAME}

xmpp_dns_auth_enable=${XMPP_SSL_ENABLE}
xmpp_auth_enable=${XMPP_SSL_ENABLE}
$xmpp_certs_config

$agent_mode_options
$tsn_agent_mode
$tsn_server_list

$sandesh_client_config

[NETWORKS]
control_network_ip=$CONTROL_NETWORK_IP

[DNS]
servers=$DNS_SERVERS_LIST

[METADATA]
metadata_proxy_secret=${METADATA_PROXY_SECRET}
$metadata_ssl_conf

[VIRTUAL-HOST-INTERFACE]
name=vhost0
ip=$VROUTER_CIDR
physical_interface=$PHYS_INT
compute_node_address=$COMPUTE_NODE_ADDRESS
$vrouter_gateway_opts

[SERVICE-INSTANCE]
netns_command=/usr/bin/opencontrail-vrouter-netns
docker_command=/usr/bin/opencontrail-vrouter-docker

[HYPERVISOR]
type = $HYPERVISOR_TYPE
$vmware_options

[FLOWS]
fabric_snat_hash_table_size = $FABRIC_SNAT_HASH_TABLE_SIZE

$qos_queueing_option

$priority_group_option

$crypt_interface_option

[SESSION]
slo_destination = $SLO_DESTINATION
sample_destination = $SAMPLE_DESTINATION

$collector_stats_config

$hugepages_option
EOM

    cleanup_lbaas_netns_config

    add_ini_params_from_env VROUTER_AGENT /etc/contrail/contrail-vrouter-agent.conf

    if [[ -n "${PRIORITY_ID}" ]] || [[ -n "${QOS_QUEUE_ID}" ]]; then
        if is_dpdk ; then
        echo "INFO: Qos provisioning not supported for dpdk vrouter. Skipping."
        else
            interface_list="${PHYS_INT}"
            if is_bonding ${PHYS_INT} ; then
                IFS=' ' read -r mode policy slaves pci_addresses bond_numa <<< $(get_bonding_parameters $phys_int)
                interface_list="${slaves//,/ }"
            fi
            /opt/contrail/utils/qosmap.py --interface_list ${interface_list}
        fi
    fi

    echo "INFO: /etc/contrail/contrail-vrouter-agent.conf"
    cat /etc/contrail/contrail-vrouter-agent.conf

    set_vnc_api_lib_ini

    if [[ -z "$K8S_TOKEN" ]]; then
        k8s_token_file=${K8S_TOKEN_FILE:-'/var/run/secrets/kubernetes.io/serviceaccount/token'}
        if [[ -f "$k8s_token_file" ]]; then
            K8S_TOKEN=`cat "$k8s_token_file"`
        fi
    fi
    cat << EOM > /etc/contrail/contrail-lbaas-auth.conf
[BARBICAN]
admin_tenant_name = ${BARBICAN_TENANT_NAME}
admin_user = ${BARBICAN_USER}
admin_password = ${BARBICAN_PASSWORD}
auth_url = $KEYSTONE_AUTH_PROTO://${KEYSTONE_AUTH_HOST}:${KEYSTONE_AUTH_ADMIN_PORT}${KEYSTONE_AUTH_URL_VERSION}
region = $KEYSTONE_AUTH_REGION_NAME
user_domain_name = $KEYSTONE_AUTH_USER_DOMAIN_NAME
project_domain_name = $KEYSTONE_AUTH_PROJECT_DOMAIN_NAME
region_name = $KEYSTONE_AUTH_REGION_NAME
insecure = ${KEYSTONE_AUTH_INSECURE}
certfile = $KEYSTONE_AUTH_CERTFILE
keyfile = $KEYSTONE_AUTH_KEYFILE
cafile = $KEYSTONE_AUTH_CA_CERTFILE
[KUBERNETES]
kubernetes_token=$K8S_TOKEN
kubernetes_api_server=${KUBERNETES_API_SERVER:-${DEFAULT_LOCAL_IP}}
kubernetes_api_port=${KUBERNETES_API_PORT:-8080}
kubernetes_api_secure_port=${KUBERNETES_API_SECURE_PORT:-6443}

EOM
}

function start_agent() {
    echo "INFO: Run start_agent"

    # spin up vrouter-agent as a child process
    if [[ $# == "0" ]]; then
      echo "INFO: Use default vrouter agent to start"
      /usr/bin/contrail-vrouter-agent &
    else
      echo "INFO: Start vrouter-agent using command: $@"
      $@ &
    fi

    local vrouter_agent_process=$!
    echo $vrouter_agent_process > /var/run/vrouter-agent.pid

    # This is to ensure decrypt interface is
    # plumbed on vrouter for processing.
    # it will be interim only till vrouter
    # agent natively have the support for
    # decrypt interface in 5.0.1
    if is_encryption_supported ; then
        if ! add_vrouter_decrypt_intf $VROUTER_DECRYPT_INTERFACE ; then
            echo "ERROR: decrypt interface was not configured. exiting..."
            exit 1
        fi
    else
        echo "INFO: Kernel version does not support vrouter to vrouter encryption - Not adding $VROUTER_DECRYPT_INTERFACE to vrouter"
    fi

    echo "INFO: vrouter agent process PID: $vrouter_agent_process"
}

# Setup kernel module and settins needed for start vhost0 network interface
function vhost0_init {
    echo "INFO: Start vhost0_init"
    pre_start_init

    # this is used for debug trace if vrouter.ko doesnt match agent
    export BUILD_VERSION=${BUILD_VERSION-"$(cat /contrail_build_version)"}
    # to explicetely disable vhost0 (for triplo where host is do it)
    export KERNEL_INIT_VHOST0=${KERNEL_INIT_VHOST0:-"true"}

    # init_vhost for dpdk case is called from dpdk container.
    #   In osp13 case there is docker service restart that leads
    #   to restart of dpdk container at the step right after network
    #   pre-config stetp. At this moment agen container is not created yet
    #   and ifup is alrady run before, so, only dpdk container
    #   can do re-init of vhost0.
    if is_dpdk || [[ "$KERNEL_INIT_VHOST0" != 'true' ]] ; then
        if ! wait_vhost0 ; then
            echo "FATAL: failed to wait vhost0"
            exit 1
        fi
    else
        if ! init_vhost0 ; then
            echo "FATAL: failed to init vhost0"
            exit 1
        fi
    fi

    # Update /dhclient-vhost0.conf with the system /etc/dhcp/dhclient.conf
    [ -e /etc/dhcp/dhclient.conf ] && cat /etc/dhcp/dhclient.conf >> /dhclient-vhost0.conf

    # For Google and Azure the underlying physical inetrface has network plumbed differently.
    # We need the following to initialize vhost0 in GC and Azure
    azure_or_gcp_or_aws=$(cat /sys/devices/virtual/dmi/id/chassis_vendor && cat /sys/devices/virtual/dmi/id/product_version)
    if [[ "${azure_or_gcp_or_aws,,}" =~ ^(.*microsoft*.|.*google*.|.*amazon*.) ]]; then
        pids=$(check_vhost0_dhcp_clients)
        if [ -z "$pids" ] ; then
            check_and_launch_dhcp_clients
        else
            # this is an important case when dhcp clients are running
            # but arp is not resolved
            if ! arp -ani vhost0 | grep vhost0 ; then
                kill $pids
                check_and_launch_dhcp_clients
            fi
        fi
    fi

    if ! check_vrouter_agent_settings ; then
        echo "FATAL: settings are not correct. Exiting..."
        exit 2
    fi

    if is_encryption_supported ; then
        if ! init_crypt0 $VROUTER_CRYPT_INTERFACE ; then
            echo "ERROR: crypt interface was not added. exiting..."
            exit 1
        fi
        if ! init_decrypt0 $VROUTER_DECRYPT_INTERFACE $VROUTER_DECRYPT_KEY ; then
            echo "ERROR: decrypt interface was not added. exiting..."
            exit 1
        fi
    else
        echo "INFO: Kernel version does not support the driver required for vrouter to vrouter encryption"
    fi

    init_sriov
}

# Setup sys signal listeners
function set_traps() {
    echo "INFO: Start set_traps"

    # Clean up files and vhost0, when SIGQUIT signal by clean-up.sh
    trap 'trap_vrouter_agent_quit' SIGQUIT

    # Terminate process only.
    # When a container/pod restarts it sends TERM and KILL signal.
    # Every time container restarts we dont want to reset data plane
    trap 'trap_vrouter_agent_term' SIGTERM SIGINT

    # Send SIGHUP signal to child process
    trap 'trap_vrouter_agent_hub' SIGHUP
}

# Create fifo pipe and pause the container until some input
# Used for k8s contrail operator
function pause_container() {
    if ls -l pause_container_pipe; then
        echo "ERROR: pipe pause_container_pipe has been already created"
        exit 1
    fi
    mkfifo pause_container_pipe
    read line <pause_container_pipe
}

# This function run the container paused by pause_container
function resume_container() {
    if ! ls -l pause_container_pipe; then
        echo "ERROR: pipe pause_container_pipe not found"
        exit 1
    fi
    echo "yes" > pause_container_pipe
}