#!/bin/sh

[ "$interface" == "vhost0" ] || exit
resolved_pid=$(ps ax | grep systemd-resolved | grep -v grep | awk '{print $1}')
[ -z $resolved_pid ] && exit

case "$reason" in
BOUND|RENEW|REBIND|REBOOT)
    ifindex=$(cat /sys/devices/virtual/net/vhost0/ifindex)
    mkdir -p /run/systemd/resolve/netif/
    cat > /run/systemd/resolve/netif/${ifindex} <<EOF
LLMNR=yes
MDNS=no
SERVERS=${new_domain_name_servers}
EOF
    kill -1 $resolved_pid
    ;;
esac
