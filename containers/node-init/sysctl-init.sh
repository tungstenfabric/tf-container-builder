#!/bin/bash

source /common.sh

# configure core_pattern for Host OS
set_ctl kernel.core_pattern /var/crashes/core.%e.%p.%h.%t

if [[ -z ${CONTRAIL_SYSCTL_TUNING+x} ]] ; then
  # by default tcp_keepalive_time is set 2h in openshift
  # which is too for failure detection
  # https://contrail-jws.atlassian.net/browse/CEM-20041?focusedCommentId=1144336)
  # values taken from RHOSP deployments
  CONTRAIL_SYSCTL_TUNING="net.ipv4.tcp_keepalive_time=5"
  CONTRAIL_SYSCTL_TUNING+=" net.ipv4.tcp_keepalive_probes=5"
  CONTRAIL_SYSCTL_TUNING+=" net.ipv4.tcp_keepalive_intvl=1"
  CONTRAIL_SYSCTL_TUNING+=" vm.max_map_count=128960"
  CONTRAIL_SYSCTL_TUNING+=" net.core.wmem_max=9160000"
fi

echo "INFO: apply sysctl: $CONTRAIL_SYSCTL_TUNING"
# accept comman and space separated list
l1=${CONTRAIL_SYSCTL_TUNING//,/ }
l2=${l1//=/ }
set_sysctls "60-tf-node-init.conf" $l2
