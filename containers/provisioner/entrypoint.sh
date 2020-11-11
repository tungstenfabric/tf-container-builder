#!/bin/bash

LOG_DIR=${LOG_DIR:-"/var/log/contrail"}
mkdir -p $LOG_DIR
chmod -f 754 $LOG_DIR
exec &> >(tee -a "$LOG_DIR/provisioner-$NODE_TYPE.log")
chmod 600 $LOG_DIR/provisioner-$NODE_TYPE.log
echo "INFO: =================== $(date) ==================="

source /common.sh

pre_start_init

# Env variables:
# NODE_TYPE = name of the component [vrouter, config, control, analytics, database, config-database, toragent]

set_vnc_api_lib_ini

if is_enabled ${MAINTENANCE_MODE} ; then
  echo "WARNING: MAINTENANCE_MODE is switched on - provision.sh is not called."
elif ! /provision.sh ; then
  echo "ERROR: provision.sh was failed. Exiting..."
  exit 1
fi

exec $@
