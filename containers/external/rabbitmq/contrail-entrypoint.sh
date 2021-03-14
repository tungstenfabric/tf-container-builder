#!/bin/bash

source /common.sh
source /functions.sh

function test_in_cluster() {
  if local status=$(rabbitmqctl cluster_status --node $1 --formatter json) ; then
    echo "$status" | python -c "$(cat <<SCRIPT
import sys, json
x=json.load(sys.stdin)
for i in filter(lambda j: j == "$2", x.get("nodes", {}).get("disc", [])):
  print(i)
SCRIPT
)"
    return
  fi
  return 1
}

# In all in one deployment there is the race between vhost0 initialization
# and own IP detection, so there is 10 retries
for i in {1..10} ; do
  my_ip_and_order=$(find_my_ip_and_order_for_node RABBITMQ)
  if [ -n "$my_ip_and_order" ]; then
    break
  fi
  sleep 1
done
if [ -z "$my_ip_and_order" ]; then
  echo "ERROR: Cannot find self ips ('$(get_local_ips)') in Rabbitmq nodes ('$RABBITMQ_NODES')"
  exit -1
fi
my_ip=$(echo $my_ip_and_order | cut -d ' ' -f 1)
echo "INFO: my_ip=$my_ip"

server_names_list=()
cluster_nodes=''
my_node=''
for server in $(echo ${RABBITMQ_NODES} | tr ',' ' '); do
  server_hostname=$(resolve_hostname_by_ip $server | cut -d '.' -f 1)
  if [[ -z "$server_hostname" ]] ; then
    echo "ERROR: hostname for $server is not resolved properly, cluster can't be set up properly."
    exit -1
  fi
  cluster_nodes+="'contrail@${server_hostname}',"
  server_names_list=($server_names_list $server_hostname)
  if server_ip=$(find_my_ip_and_order_for_node_list "$server" | cut -d ' ' -f 1) && [[ ",$server_ip," =~ ",$my_ip," ]] ; then
    my_node=$server_hostname
    echo "INFO: my_node=$server_hostname"
  fi
done

dist_ip=$(echo $my_ip | tr '.' ',')

RABBITMQ_NODENAME=contrail@$my_node
RABBITMQ_MGMT_PORT=$((RABBITMQ_NODE_PORT+10000))
RABBITMQ_DIST_PORT=$((RABBITMQ_NODE_PORT+20000))

# check ssl settings consistency
if is_enabled $RABBITMQ_USE_SSL ; then
  ssl_dir="/tmp/rabbitmq-ssl"
  mkdir -p "$ssl_dir"
  for cert in CERTFILE KEYFILE CACERTFILE ; do
    var="RABBITMQ_SSL_${cert}"
    val="${!var}"
    # if val is empty - do not fail
    if [[ -z "$val" ]]; then
      continue
    fi
    if [ ! -f "$val" ] ; then
      echo "ERROR: SSL is requested, but missing required configuration: $var (value is empty or file couldn't be found"
      exit -1
    fi
    # as we know that certs were stored by root then here we will copy them to temporary place and set rabbitmq ownership
    newFile="$ssl_dir/$cert"
    cat "$val" > $newFile
    chown rabbitmq:rabbitmq "$newFile"
    chmod 0400 "$newFile"
    eval 'export '$var'="$newFile"'
  done
fi

# un-export all rabbitmq variables - if entrypoint of rabbitmq founds them then it creates own config and rewrites own
export -n RABBITMQ_NODE_PORT RABBITMQ_DIST_PORT RABBITMQ_DEFAULT_USER RABBITMQ_DEFAULT_PASS RABBITMQ_DEFAULT_VHOST
for name in CACERTFILE CERTFILE KEYFILE DEPTH FAIL_IF_NO_PEER_CERT VERIFY ; do
  export -n RABBITMQ_SSL_$name RABBITMQ_MANAGEMENT_SSL_$name
done

echo "INFO: RABBITMQ_NODENAME=$RABBITMQ_NODENAME, RABBITMQ_NODE_PORT=$RABBITMQ_NODE_PORT"

# to be able to run rabbitmqctl without params
echo "RABBITMQ_NODENAME=contrail@$my_node" > /etc/rabbitmq/rabbitmq-env.conf
echo "HOME=/var/lib/rabbitmq" >> /etc/rabbitmq/rabbitmq-env.conf
if is_enabled $RABBITMQ_USE_SSL ; then
  echo 'RABBITMQ_CTL_ERL_ARGS="-proto_dist inet_tls"' >> /etc/rabbitmq/rabbitmq-env.conf
fi

# save cookie to file (otherwise rabbitmqctl set it to wrong value)
if [[ -n "$RABBITMQ_ERLANG_COOKIE" ]] ; then
  cookie_file="/var/lib/rabbitmq/.erlang.cookie"
  echo $RABBITMQ_ERLANG_COOKIE > $cookie_file
  chmod 600 $cookie_file
  chown rabbitmq:rabbitmq $cookie_file
fi

if is_enabled $RABBITMQ_USE_SSL ; then
  cat << EOF > /etc/rabbitmq/rabbitmq.config
[
   {rabbit, [ {tcp_listeners, [ ]},
              {ssl_listeners, [{"${my_ip}", ${RABBITMQ_NODE_PORT}}]},
              {ssl_options,
                        [{cacertfile, "${RABBITMQ_SSL_CACERTFILE}"},
                         {certfile, "${RABBITMQ_SSL_CERTFILE}"},
                         {keyfile, "${RABBITMQ_SSL_KEYFILE}"},
                         {verify, verify_peer},
                         {fail_if_no_peer_cert, ${RABBITMQ_SSL_FAIL_IF_NO_PEER_CERT}}]
              },
EOF
else
  cat << EOF > /etc/rabbitmq/rabbitmq.config
[
   {rabbit, [ {tcp_listeners, [{"${my_ip}", ${RABBITMQ_NODE_PORT}}]},
              {ssl_listeners, [ ]},
EOF
fi

cat << EOF >> /etc/rabbitmq/rabbitmq.config
              {cluster_partition_handling, ${RABBITMQ_CLUSTER_PARTITION_HANDLING}},
              {loopback_users, []},
              {cluster_nodes, {[${cluster_nodes::-1}], disc}},
              {vm_memory_high_watermark, 0.8},
              {disk_free_limit,50000000},
              {log_levels,[{connection, info},{mirroring, info}]},
              {heartbeat, ${RABBITMQ_HEARTBEAT_INTERVAL}},
              {delegate_count,20},
              {channel_max,5000},
              {tcp_listen_options,
                        [{backlog, 128},
                         {nodelay, true},
                         {exit_on_close, false},
                         {keepalive, true}]
              },
              {collect_statistics_interval, 60000},
              {default_user, <<"${RABBITMQ_USER}">>},
              {default_pass, <<"${RABBITMQ_PASSWORD}">>}
            ]
   },
   {rabbitmq_management, [
        {listener, [{port, ${RABBITMQ_MGMT_PORT}}]},
        {load_definitions, "/etc/rabbitmq/definitions.json"}
      ]
    },
   {rabbitmq_management_agent, [ {force_fine_statistics, true} ] },
   {kernel, [{net_ticktime,  60}, {inet_dist_use_interface, {${dist_ip}}}, {inet_dist_listen_min, ${RABBITMQ_DIST_PORT}}, {inet_dist_listen_max, ${RABBITMQ_DIST_PORT}}]}
].
EOF

if [[ -n "$RABBITMQ_MIRRORED_QUEUE_MODE" ]] ; then
  salt=$(cat /dev/urandom | tr -d '\0' | head --bytes=4 | xxd -ps -c 256)
  pwd=$(echo -n "${RABBITMQ_PASSWORD}" | xxd -ps -c 256)
  sha256=$(echo -n "$salt$pwd" | xxd -r -p | sha256sum --binary | head -c 64)
  b64=$(echo -n "${salt}${sha256}" | xxd -r -p | base64 -w 0)
  cat << EOF > /etc/rabbitmq/definitions.json
{
  "users": [{
    "name": "$RABBITMQ_USER",
    "password_hash": "$b64",
    "hashing_algorithm": "rabbit_password_hashing_sha256",
    "tags": "administrator"
  }],
  "vhosts": [{
    "name": "/"
  }],
  "permissions": [{
    "user": "$RABBITMQ_USER",
    "vhost": "/",
    "configure": ".*",
    "write": ".*",
    "read": ".*"
  }],
"policies": [
    {
      "vhost": "/",
      "name": "ha",
      "pattern": "^(?!amq\.).*",
      "definition": {
          "ha-mode": "$RABBITMQ_MIRRORED_QUEUE_MODE",
          "ha-sync-mode": "automatic",
          "ha-sync-batch-size": 5
        }
    }
  ]
}
EOF
else
  cat << EOF > /etc/rabbitmq/definitions.json
{}
EOF
fi

# copy-paste from base container because there is no way to reach this blocks of code there
if is_enabled $RABBITMQ_USE_SSL && [[ "$1" == rabbitmq* ]]; then
  combinedSsl="$ssl_dir/combined.pem"
  # Create combined cert
  cat "$RABBITMQ_SSL_CERTFILE" "$RABBITMQ_SSL_KEYFILE" > "$combinedSsl"
  chown rabbitmq:rabbitmq "$combinedSsl"
  chmod 0400 "$combinedSsl"
  # More ENV vars for make clustering happiness
  # we don't handle clustering in this script, but these args should ensure
  # clustered SSL-enabled members will talk nicely
  export ERL_SSL_PATH="$(erl -eval 'io:format("~p", [code:lib_dir(ssl, ebin)]),halt().' -noshell)"
  sslErlArgs="-pa $ERL_SSL_PATH -proto_dist inet_tls -ssl_dist_opt server_certfile $combinedSsl -ssl_dist_opt server_secure_renegotiate true client_secure_renegotiate true"
  export RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS="${RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS:-} $sslErlArgs"
  export RABBITMQ_CTL_ERL_ARGS="${RABBITMQ_CTL_ERL_ARGS:-} $sslErlArgs"
fi
mkdir -p /var/log/rabbitmq
chown -R rabbitmq:rabbitmq /var/log/rabbitmq
function setup_log_dir() {

  local path=$1
  local log_dir
  local log_name
  if [[ -n "$path" && "$path" != '-' ]] ; then
    log_dir=$(dirname $path)
    mkdir -p $log_dir
    # move old logs if any to new folder
    log_name=$(basename $path)
    mv -n $(dirname $log_dir)/${log_name}* ${log_dir}/ 2>/dev/null
    touch "$path"
    chown rabbitmq:rabbitmq "$path"
  fi
}

setup_log_dir $RABBITMQ_LOGS
setup_log_dir "$RABBITMQ_SASL_LOGS"

# NB. wait & join explicitly an existing cluster started by
# the first server otherwise we face a race incurring a
# partitioning.
leader_node="${server_names_list[0]}"
if [[ "${leader_node}" != "$my_node" ]] ; then
  echo "INFO: delay node $my_node start until first node starts..."
  leader_nodename=contrail@$leader_node
  while true; do
    rabbitmqctl --node "${RABBITMQ_NODENAME}" shutdown || true
    /docker-entrypoint.sh rabbitmq-server -detached || exit 1
    
    # NB. working ping doesn't mean the process is able to report status
    while ! rabbitmqctl --node $RABBITMQ_NODENAME ping ; do
      sleep $(( 5 + $RANDOM % 5 ))
      date
    done  
    sleep $(( 5 + $RANDOM % 5 ))
    
    in_cluster=""
    for i in {1..5} ; do
      if in_cluster=$(test_in_cluster $RABBITMQ_NODENAME $bootstrap_node) ; then
        break
      fi
      sleep $(( 5 + $RANDOM % 5 ))
      date
    done
    if [ -n "$in_cluster" ] ; then
      # alrady in cluster
      break
    fi

    # need to re-join
    # stop app
    rabbitmqctl --node $RABBITMQ_NODENAME stop_app
    # wait main bootstrap node
    while ! rabbitmqctl --node $bootstrap_node ping ; do
      sleep $(( 5 + $RANDOM % 5 ))
      date
    done
    sleep $(( 5 + $RANDOM % 5 ))
    rabbitmqctl --node $bootstrap_node forget_cluster_node $RABBITMQ_NODENAME
    rabbitmqctl --node $RABBITMQ_NODENAME reset
    rabbitmqctl --node $RABBITMQ_NODENAME join_cluster $bootstrap_node || continue
    break
  done
  rabbitmqctl --node "${RABBITMQ_NODENAME}" shutdown
fi
echo "INFO: $(date): /docker-entrypoint.sh $@"
exec  /docker-entrypoint.sh "$@"
