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

if [[ "$CONFIG_API_WORKER_COUNT" == 1 ]] ; then
cat > /etc/contrail/contrail-api.conf << EOM
[DEFAULTS]
listen_ip_addr=${host_ip}
listen_port=$CONFIG_API_PORT
http_server_port=${CONFIG_API_INTROSPECT_PORT}
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

$config_api_certs_config

rabbit_server=$RABBITMQ_SERVERS
$rabbit_config
$kombu_ssl_config

collectors=$COLLECTOR_SERVERS

$sandesh_client_config

$collector_stats_config

$neutron_section
EOM

add_ini_params_from_env API /etc/contrail/contrail-api.conf

else
ADMIN_PORT=8095
for ((index=0; index<$CONFIG_API_WORKER_COUNT; ++index)) ; do
  if [[ "$index" == 0 ]] ; then
    http_server_port=${CONFIG_API_INTROSPECT_PORT}
    admin_port=${ADMIN_PORT}
  else
    http_server_port=$((10000 + CONFIG_API_INTROSPECT_PORT + index - 1))
    admin_port=$((20000 + ADMIN_PORT + index - 1))
  fi

cat > /etc/contrail/contrail-api-$index.conf << EOM
[DEFAULTS]
listen_ip_addr=${host_ip}
listen_port=$CONFIG_API_PORT
http_server_port=${http_server_port}
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

admin_port=${admin_port}
worker_id=$index

rabbit_server=$RABBITMQ_SERVERS
$rabbit_config
$kombu_ssl_config

collectors=$COLLECTOR_SERVERS

$sandesh_client_config

$collector_stats_config

$neutron_section
EOM
done

if is_enabled ${CONFIG_API_SSL_ENABLE} ; then
  uwsgi_socket="https-socket = ${host_ip}:$CONFIG_API_PORT,${CONFIG_API_SERVER_CERTFILE},${CONFIG_API_SERVER_KEYFILE}"
else
  uwsgi_socket="protocol = http
  socket = ${host_ip}:$CONFIG_API_PORT"
fi
cat> /etc/contrail/contrail-api-uwsgi.ini <<EOM
[uwsgi]
strict
master
single-interpreter
vacuum
need-app
workers = ${CONFIG_API_WORKER_COUNT}
gevent = ${CONFIG_API_MAX_REQUESTS}
lazy-apps

$uwsgi_socket
module = vnc_cfg_api_server.uwsgi_api_server:get_apiserver()
so-keepalive
reuse-port
uid = $CONTRAIL_UID
gid = $CONTRAIL_GID
EOM
fi

set_third_party_auth_config
set_vnc_api_lib_ini

upgrade_old_logs "contrail-api"

if [[ "$CONFIG_API_WORKER_COUNT" == 1 ]] ; then
  /usr/bin/contrail-api --conf_file /etc/contrail/contrail-api.conf --conf_file /etc/contrail/contrail-keystone-auth.conf --worker_id 0
else
  /usr/bin/uwsgi /etc/contrail/contrail-api-uwsgi.ini
fi

run_service "$@"
