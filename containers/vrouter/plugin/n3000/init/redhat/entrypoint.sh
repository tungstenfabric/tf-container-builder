#!/usr/bin/env bash

script_dir="/etc/sysconfig/network-scripts/n3000"
work_dir="/var/lib/contrail/n3000"
lock_file="/var/lib/contrail/n3000/n3000-plugin-init-done"

mkdir -p "${work_dir}/site_packages"
mkdir -p "${script_dir}"

rm -f /etc/sysconfig/network-scripts/ifcfg-npac*

cp /n3000-* "${script_dir}/"

cp -r /opt/n3000/* "${work_dir}/"

. /n3000-env.sh "${lock_file}" "${work_dir}"

touch "${lock_file}"

echo "INFO: N3000 plugin init container setup done."
