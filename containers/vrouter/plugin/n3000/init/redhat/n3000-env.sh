#/usr/bin/env bash

declare -a env_vars=( N3000_VFs_NUM N3000_VFs_QUEUE_NUM N3000_VDPA_ENABLED N3000_BONDING_MODE N3000_VDPA_MAPPING_ENABLED N3000_INSERT_MODE N3000_PF0_DRIVER N3000_DROP_OFFLOAD_ENABLED N3000_AGING_LCORE_ENABLED N3000_CUSTOM_VF0_NAME )
env_file="/etc/sysconfig/network-scripts/n3000/n3000-env"

[ -f $env_file ] && rm $env_file
touch $env_file

for var in ${env_vars[@]}; do
    evaled_var="export $var=\"\${$var:-$(eval echo \${$var})}\""
    echo $evaled_var >> $env_file
done
