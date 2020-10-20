#!/bin/bash -x

# these next folders must be mounted to compile vrouter.ko in ubuntu: /usr/src /lib/modules

echo "INFO: Compiling vrouter kernel module for ubuntu..."
current_kver=`uname -r`
echo "INFO: Detected kernel version is $current_kver"

if [ ! -f "/contrail_version" ] ; then
  echo "ERROR: There is no version specified in /contrail_version file. Exiting..."
  exit 1
fi
contrail_version="$(cat /contrail_version)"
echo "INFO: use vrouter version $contrail_version"

vrouter_dir="/usr/src/vrouter-${contrail_version}"
mkdir -p $vrouter_dir
cp -ap /vrouter_src/. ${vrouter_dir}/
chmod -R 755  ${vrouter_dir}
rm -rf /vrouter_src
templ=$(cat /opt/contrail/src/dkms.conf)
content=$(eval "echo \"$templ\"")
echo "$content" > $vrouter_dir/dkms.conf

mkdir -p /vrouter/${contrail_version}/build/include/
mkdir -p /vrouter/${contrail_version}/build/dp-core
is_installed=$(dkms status -m vrouter -v "${contrail_version}")
if [[ -z "$is_installed" ]] ; then
  dkms --verbose add -m vrouter -v "${contrail_version}"
fi
echo "INFO: run dkms build for current kernel $current_kver"
if ! dkms --verbose build -m vrouter -v "${contrail_version}" ; then
  cat /var/lib/dkms/vrouter/${contrail_version}/build/make.log
else
  dkms --verbose install -m vrouter -v "${contrail_version}" --force
fi

echo "INFO: DKMS run autoinstall for other kernel versions"
kernel_modules=$(ls /lib/modules)
for kver in $kernel_modules ; do
  if [[ $kver != $current_kver ]]; then
    dkms autoinstall -k $kver
  fi
done
depmod -a

echo "INFO: check built modules:"
find /lib/modules/ | grep vrouter
echo "INFO: check vrouter.ko was built for current kernel"
ls -l /lib/modules/$current_kver/updates/dkms/vrouter.ko || exit 1

touch $vrouter_dir/module_compiled

# copy vif util to host
if [[ -d /host/bin && ! -f /host/bin/vif ]] ; then
  /bin/cp -f /contrail_tools/usr/bin/vif /host/bin/vif
  chmod +x /host/bin/vif
fi

# remove third-party folder
if [[ -d /root/contrail/third_party ]] ; then
  rm -rf /root/contrail/third_party
fi
