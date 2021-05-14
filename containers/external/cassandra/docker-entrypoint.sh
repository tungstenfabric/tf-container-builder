#!/bin/bash -e

source /common.sh

# first arg is `-f` or `--some-option`
# or there are no args
if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
	set -- $CASSANDRA_USER -f "$@"
fi

_ip_address() {
	# scrape the first non-localhost IP address of the container
	# in Swarm Mode, we often get two IPs -- the container IP, and the (shared) VIP, and the container IP should always be first
	ip address | awk '
		$1 == "inet" && $NF != "lo" {
			gsub(/\/.+$/, "", $2)
			print $2
			exit
		}
	'
}

# "sed -i", but without "mv" (which doesn't work on a bind-mounted file, for example)
_sed-in-place() {
	local filename="$1"; shift
	local tempFile
	tempFile="$(mktemp)"
	sed "$@" "$filename" > "$tempFile"
	cat "$tempFile" > "$filename"
	rm "$tempFile"
}

function is_process_dead() {
	if kill -0 $cassandra_pid >/dev/null 2>&1; then
		return 1
	fi
}

function trap_cassandra_term() {
	if [ -z "$cassandra_pid" ]; then
		return
	fi
	if is_process_dead; then
		return
	fi
	if ! ${CASSANDRA_HOME}/bin/nodetool -p ${CASSANDRA_JMX_LOCAL_PORT} stopdaemon 2>&1 ; then
		echo "WARN: stopping the daemon has failed"
	fi
	if is_process_dead; then
		return
	fi
	echo "INFO: terminate process $cassandra_pid"
	kill $cassandra_pid
	if wait_cmd_success "is_process_dead" 3 5 ; then
		return
	fi
	echo "INFO: kill process $cassandra_pid"
	kill -KILL $cassandra_pid &>/dev/null
	wait_cmd_success "is_process_dead" 3 5
	exit $?
}

if [ "$1" = 'cassandra' ]; then
	: ${CASSANDRA_RPC_ADDRESS='0.0.0.0'}

	: ${CASSANDRA_LISTEN_ADDRESS='auto'}
	if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
		CASSANDRA_LISTEN_ADDRESS="$(_ip_address)"
	fi

	: ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

	if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
		CASSANDRA_BROADCAST_ADDRESS="$(_ip_address)"
	fi
	: ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

	if [ -n "${CASSANDRA_NAME:+1}" ]; then
		: ${CASSANDRA_SEEDS:="cassandra"}
	fi
	: ${CASSANDRA_SEEDS:="$CASSANDRA_BROADCAST_ADDRESS"}

	_sed-in-place "$CASSANDRA_CONFIG/cassandra.yaml" \
		-r 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/'

	for yaml in \
		broadcast_address \
		broadcast_rpc_address \
		cluster_name \
		endpoint_snitch \
		listen_address \
		num_tokens \
		rpc_address \
		start_rpc \
		file_cache_size_in_mb \
	; do
		var="CASSANDRA_${yaml^^}"
		val="${!var}"
		if [ "$val" ]; then
			_sed-in-place "$CASSANDRA_CONFIG/cassandra.yaml" \
				-r 's/^(# )?('"$yaml"':).*/\2 '"$val"'/'
		fi
	done

	for rackdc in dc rack; do
		var="CASSANDRA_${rackdc^^}"
		val="${!var}"
		if [ "$val" ]; then
			_sed-in-place "$CASSANDRA_CONFIG/cassandra-rackdc.properties" \
				-r 's/^('"$rackdc"'=).*/\1 '"$val"'/'
		fi
	done
fi

chown -R ${CASSANDRA_USER}:${CASSANDRA_GROUP} $CASSANDRA_CONFIG $CASSANDRA_LIB $CASSANDRA_LOG

CONTRAIL_UID=$( id -u $CASSANDRA_USER )
CONTRAIL_GID=$( id -g $CASSANDRA_GROUP )

trap 'trap_cassandra_term' SIGTERM SIGINT
do_run_service "$@" &
cassandra_pid=$!

wait $cassandra_pid
