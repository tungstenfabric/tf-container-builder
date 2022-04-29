#!/usr/bin/env bash

mkdir -p /var/lib/contrail/vrouter/n3000/site_packages || true
mkdir -p /etc/sysconfig/network-scripts/n3000 || true

rm -f /etc/sysconfig/network-scripts/ifcfg-npac*

cp /n3000_defs /etc/sysconfig/network-scripts/n3000/
cp /n3000-driver-mgmt.sh /etc/sysconfig/network-scripts/n3000/
cp /n3000-offload-config.sh /etc/sysconfig/network-scripts/n3000/
cp /n3000-init.sh /etc/sysconfig/network-scripts/n3000/
cp /n3000-fw-manager.sh /etc/sysconfig/network-scripts/n3000/
cp /n3000-int-restore.sh /etc/sysconfig/network-scripts/n3000/

cp -r /opt/n3000/* /var/lib/contrail/vrouter/n3000/

. /n3000-env.sh
