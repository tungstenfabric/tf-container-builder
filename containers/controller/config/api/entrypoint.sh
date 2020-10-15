#!/bin/bash

source /common.sh

pre_start_init
wait_config_api_certs_if_ssl_enabled

host_ip='0.0.0.0'
if ! is_enabled ${CONFIG_API_LISTEN_ALL}; then
  host_ip=$(get_listen_ip_for_node CONFIG)
fi

introspect_port_list=($(echo $CONFIG_API_INTROSPECT_PORTS | sed 's/,/ /g'))
admin_port_list=($(echo $CONFIG_API_ADMIN_PORTS | sed 's/,/ /g'))
len_introspect_port_list=${#introspect_port_list[@]}
len_admin_port_list=${#admin_port_list[@]}

if (( CONFIG_API_WORKER_COUNT > 3 )) ; then
  if (( CONFIG_API_WORKER_COUNT != len_introspect_port_list )) ; then
    echo "Incorrect arguments for introspect ports" 1>&2
    exit 1
  fi
  if (( CONFIG_API_WORKER_COUNT != len_admin_port_list )) ; then
    echo "Incorrect arguments for admin ports" 1>&2
    exit 1
  fi
fi

cassandra_server_list=$(echo $CONFIGDB_SERVERS | sed 's/,/ /g')
config_api_certs_config=''
uwsgi_socket="protocol = http\nsocket = ${host_ip}:$CONFIG_API_PORT"
if is_enabled ${CONFIG_API_SSL_ENABLE} ; then
  if (( CONFIG_API_WORKER_COUNT == 1 )) ; then
    read -r -d '' config_api_certs_config << EOM || true
config_api_ssl_enable=${CONFIG_API_SSL_ENABLE}
config_api_ssl_certfile=${CONFIG_API_SERVER_CERTFILE}
config_api_ssl_keyfile=${CONFIG_API_SERVER_KEYFILE}
config_api_ssl_ca_cert=${CONFIG_API_SERVER_CA_CERTFILE}
EOM
  else
    uwsgi_socket="https-socket = ${host_ip}:$CONFIG_API_PORT,${CONFIG_API_SERVER_CERTFILE},${CONFIG_API_SERVER_KEYFILE}"
  fi
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

admin_port=$CONFIG_API_ADMIN_PORT
http_server_port=$CONFIG_API_INTROSPECT_PORT
for (( index=0; index < CONFIG_API_WORKER_COUNT; ++index )) ; do
  cat > /etc/contrail/contrail-api-$index.conf << EOM
[DEFAULTS]
listen_ip_addr=${host_ip}
listen_port=$CONFIG_API_PORT
http_server_port=${http_server_port}
http_server_ip=$(get_introspect_listen_ip_for_node CONFIG)
log_file=$CONTAINER_LOG_DIR/contrail-api-${index}.log
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

admin_port=${admin_port}
worker_id=${index}

rabbit_server=$RABBITMQ_SERVERS
$rabbit_config
$kombu_ssl_config

collectors=$COLLECTOR_SERVERS

$sandesh_client_config

$collector_stats_config

$neutron_section
EOM

  add_ini_params_from_env API /etc/contrail/contrail-api-$index.conf

  http_server_port=${introspect_port_list[index+1]}
  admin_port=${admin_port_list[index+1]}

done

if (( CONFIG_API_WORKER_COUNT > 1 )) ; then
  service_cmd="$(which uwsgi) /etc/contrail/contrail-api-uwsgi.ini"
  cat > /etc/contrail/contrail-api-uwsgi.ini <<EOM
[uwsgi]
strict
master
single-interpreter
vacuum
need-app
plugins = python, gevent
workers = ${CONFIG_API_WORKER_COUNT}
gevent = ${CONFIG_API_MAX_REQUESTS}
lazy-apps

$(printf '%b\n' "$uwsgi_socket")
module = vnc_cfg_api_server.uwsgi_api_server:get_apiserver()
so-keepalive
reuse-port
EOM
else
  service_cmd="/usr/bin/contrail-api --conf_file /etc/contrail/contrail-api-0.conf --conf_file /etc/contrail/contrail-keystone-auth.conf --worker_id 0"
fi

set_third_party_auth_config
set_vnc_api_lib_ini

upgrade_old_logs "contrail-api"

run_service $service_cmd
