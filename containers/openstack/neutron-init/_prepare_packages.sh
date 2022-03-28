#!/bin/bash -ex

# download all requried version of package python-neutron-lbaas
# appropriate version based on OPENSTACK_VERSION will be chosen and installed at runtime

pkd_dir="/opt/packages"
mkdir -p $pkd_dir
for version in newton ocata queens rocky stein; do
  echo "INFO: Using $version"
  url=$(repoquery -q --location python-neutron-lbaas-${version})
  if [[ -z "$url" ]]; then
    echo "ERROR: python-neutron-lbaas-$version couldn't be found in repo but it must be present somewhere."
    exit 1
  fi
  pkg_name=$(basename $url)
  curl -s -o $pkd_dir/$pkg_name $url
done
