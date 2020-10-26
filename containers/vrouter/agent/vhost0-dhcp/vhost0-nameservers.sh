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

    search_suffix=""
    if [ -n "${new_domain_name}" ]; then
      search_suffix=${new_domain_name}
    fi
    if [ -n "${new_domain_search}" ]; then
      search_suffix=${new_domain_search}
    fi
    if [ -n "${search_suffix}" ]; then
      mkdir -p /host/etc/systemd
      cat > /host/etc/systemd/resolved.conf <<EOF
[Resolve]
Domains=${search_suffix}
EOF
    fi
    kill -1 $resolved_pid
    ;;
esac
