#!/bin/bash -e

source /common.sh

# redis is needed for WebUI also. WebUI works with 127.0.0.1
# If WebUI is placed on the same node with analytics - redis will listen on two IP-s and analytics and WebUI will work well.
# If WebUI is placed on different node than analitics - redis on the node with WebUI will listen only 127.0.0.1 and it is sufficient for WebUI.

# it doesn't matter here if REDIS_NODES will have duplicates
# first list must be ANALYTICSNODES and if IP can be found there then it doesn't matter
# what is in WEBUI_NODES
REDIS_NODES="${REDIS_NODES:-$ANALYTICS_NODES,$WEBUI_NODES}"

if [[ -z "$REDIS_LISTEN_ADDRESS" && -n "$REDIS_NODES" ]]; then
  for i in {1..10} ; do
    my_ip_and_order=$(find_my_ip_and_order_for_node REDIS)
    if [ -n "$my_ip_and_order" ]; then
      break
    fi
    sleep 1
  done
  redis_node_ip=$(echo $my_ip_and_order | cut -d ' ' -f 1)
  [ -n "$redis_node_ip" ] && REDIS_LISTEN_ADDRESS=${redis_node_ip}
fi

redis_opts="--lua-time-limit 15000"
redis_opts+=" --dbfilename ''"
redis_opts+=' --bind 127.0.0.1'
if ! is_enabled ${REDIS_SSL_ENABLE} && [[ "$REDIS_LISTEN_ADDRESS" != "127.0.0.1" ]] ; then
    [ -n "$REDIS_LISTEN_ADDRESS" ] && redis_opts+=" $REDIS_LISTEN_ADDRESS"
fi
[ -n "$REDIS_SERVER_PORT" ] && redis_opts+=" --port $REDIS_SERVER_PORT"
[ -n "$REDIS_SERVER_PASSWORD" ] && redis_opts+=" --requirepass $REDIS_SERVER_PASSWORD"
[ -n "$REDIS_PROTECTED_MODE" ] && redis_opts+=" --protected-mode $REDIS_PROTECTED_MODE"

echo "INFO: redis cmd options: $redis_opts"

CONTRAIL_UID=$( id -u redis )
CONTRAIL_GID=$( id -g redis )

find . \! -user redis -exec chown redis '{}' +

do_run_service $@ $redis_opts
