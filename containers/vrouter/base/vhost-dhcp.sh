#!/bin/bash

declare -x interface=vhost0

if [ ! -d "/etc/sysconfig/network-scripts" ]; then
  ln -s /network-scripts /etc/sysconfig/network-scripts
fi

/sbin/dhclient-script
