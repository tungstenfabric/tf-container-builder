#!/bin/bash

source /common.sh

pre_start_init
wait_config_api_certs_if_ssl_enabled

host_ip='0.0.0.0'
if ! is_enabled ${CONFIG_API_LISTEN_ALL}; then
  host_ip=$(get_listen_ip_for_node CONFIG)
fi

cassandra_server_list=$(echo $CONFIGDB_SERVERS | sed 's/,/ /g')
if is_enabled ${CONFIG_API_SSL_ENABLE} ; then
  read -r -d '' config_api_certs_config << EOM || true
config_api_ssl_enable=${CONFIG_API_SSL_ENABLE}
config_api_ssl_certfile=${CONFIG_API_SERVER_CERTFILE}
config_api_ssl_keyfile=${CONFIG_API_SERVER_KEYFILE}
config_api_ssl_ca_cert=${CONFIG_API_SERVER_CA_CERTFILE}
EOM
else
  config_api_certs_config=''
fi

if is_enabled ${FWAAS_ENABLE} ; then
  read -r -d '' neutron_section << EOM || true
[NEUTRON]
fwaas_enabled=True
EOM
else
  neutron_section=''
fi

mkdir -p /etc/contrail
for count in {0..4}
do
cat > /etc/contrail/contrail-api-$count.conf << EOM
[DEFAULTS]
listen_ip_addr=${host_ip}
listen_port=$CONFIG_API_PORT
http_server_port=$count${CONFIG_API_INTROSPECT_PORT}
http_server_ip=$(get_introspect_listen_ip_for_node CONFIG)
log_file=$CONTAINER_LOG_DIR/contrail-api.log
log_level=$LOG_LEVEL
log_local=$LOG_LOCAL
list_optimization_enabled=${CONFIG_API_LIST_OPTIMIZATION_ENABLED:-True}
auth=$AUTH_MODE
aaa_mode=$AAA_MODE
cloud_admin_role=$CLOUD_ADMIN_ROLE
global_read_only_role=$GLOBAL_READ_ONLY_ROLE
cassandra_server_list=$cassandra_server_list
cassandra_use_ssl=${CASSANDRA_SSL_ENABLE,,}
cassandra_ca_certs=$CASSANDRA_SSL_CA_CERTFILE
zk_server_ip=$ZOOKEEPER_SERVERS

worker_id=$i

rabbit_server=$RABBITMQ_SERVERS
$rabbit_config
$kombu_ssl_config

collectors=$COLLECTOR_SERVERS

$sandesh_client_config

$collector_stats_config

$neutron_section
EOM

cat> /etc/contrail/contrail-api-uwsgi.ini <<EOM
[uwsgi]
master = true
single-interpreter = true
workers = 5
gevent = 1000
protocol = http
socket = 0.0.0.0:8082
module = vnc_cfg_api_server.uwsgi_api_server:get_bottle_server()
uid = contrail
gid = contrail
lazy-apps = true
EOM

set_third_party_auth_config
set_vnc_api_lib_ini

upgrade_old_logs "contrail-api"

run_service "$@"
