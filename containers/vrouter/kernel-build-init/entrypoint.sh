#!/bin/bash -x

# these next folders must be mounted to compile vrouter.ko in ubuntu: /usr/src /lib/modules

echo "INFO: Compiling vrouter kernel module for ubuntu..."
kver=`uname -r`
echo "INFO: Detected kernel version is $kver"

if [ ! -f "/contrail_version" ] ; then
  echo "ERROR: There is no version specified in /contrail_version file. Exiting..."
  exit 1
fi
contrail_version="$(cat /contrail_version)"
echo "INFO: use vrouter version $contrail_version"

if [ ! -d "/usr/src/linux-headers-$kver" ] ; then
  echo "ERROR: There is no kernel headers in /usr/src for current kernel. Exiting..."
  exit 1
fi

if [ ! -f lib/modules/$kver/updates/dkms/vrouter.ko ] ; then
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
    dkms --verbose add -m vrouter -v "${contrail_version}"
    dkms --verbose build -m vrouter -v "${contrail_version}"
    cat /var/lib/dkms/vrouter/${contrail_version}/build/make.log
    dkms --verbose install -m vrouter -v "${contrail_version}"
    depmod -a
fi

# check vrouter.ko was built
ls -l /lib/modules/$kver/updates/dkms/vrouter.ko || exit 1

kernel_modules=$(ls /lib/modules)
for kver in $kernel_modules ; do
    # vrouter doesn't support kernels version 5, remove check after fix
    if ! [[ "$kver" =~ ^5. ]] ; then
        if [ ! -f "/lib/modules/$kver/updates/dkms/vrouter.ko" ]; then
            echo "DKMS auto installing for kernel $kver"
            dkms autoinstall -k $kver
            depmod -a

            # check vrouter.ko was built
            ls -l /lib/modules/$kver/updates/dkms/vrouter.ko || exit 1
        fi
    fi
done

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
