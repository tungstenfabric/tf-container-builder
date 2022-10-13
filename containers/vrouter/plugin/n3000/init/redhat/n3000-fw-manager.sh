#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/n3000/n3000-mgmt.sh

function show_firmware_version {
# Expected argument:
# $1 - PCI address of mgmt dev
    local mgmt_dev=$1

    if [[ -z "${mgmt_dev}" ]]; then
        fw_version_found=""
        return
    fi

    check_module "uio_pci_generic"
    unbind_driver "${mgmt_dev}"
    override_driver "${mgmt_dev}" "uio_pci_generic"

    fw_version_found=$(n3k-info --file-prefix n3k-info --pci-whitelist ${mgmt_dev},insert_type=csr -- --device-name ${mgmt_dev} --show-firmware-version 2>/dev/null | awk '/FIRMWARE_VERSION:/ { print $2 }')
}

function update_firmware {
    fpgasupdate --log-level info $1/pac-n3000-secure-update-signed_ssl.bin
}

src_dir=$1
fw_version_required=$2

show_firmware_version "$(lspci -nnD | awk '/1af4:1041/ { print $1 }' | head -n 1)"

if [ "${fw_version_found}" != "${fw_version_required}" ]; then
    unbind_n3000_xxv710 || true
    update_firmware "${src_dir}/fw"
fi
