#!/usr/bin/env bash

script_dir="/etc/sysconfig/network-scripts/n3000"
work_dir="/var/lib/contrail/n3000"
lock_file="/var/lib/contrail/n3000/n3000-plugin-init-done"

[ -f "${lock_file}" ] && rm "${lock_file}"

mkdir -p "${work_dir}/site_packages"
mkdir -p "${script_dir}"

cp /n3000-* "${script_dir}/"

cp -r /opt/n3000/* "${work_dir}/"

chmod +x /n3000-env.sh

/n3000-env.sh "${lock_file}" "${work_dir}"

chmod +x "${script_dir}/n3000-*"

for npac in $(ip l | awk '/ npac/ { print substr($2,0,length($2)-1); }'); do
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-${npac}
DEVICE=${npac}
ONBOOT=no
HOTPLUG=no
NM_CONTROLLED=no
BOOTPROTO=none
EOF

done

touch "${lock_file}"

echo "INFO: N3000 plugin init container setup done."

echo "DEBUG: /etc/sysconfig/network-scripts directory content:"
echo "-----------------------------------------------------"

find /etc/sysconfig/network-scripts/ -type f -exec ls -al {} +

echo "-----------------------------------------------------"
