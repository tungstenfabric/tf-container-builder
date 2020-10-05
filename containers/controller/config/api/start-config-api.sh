#!/bin/bash

source /common.sh

if (( CONFIG_API_WORKER_COUNT > 1 )) ; then
  cmd="/usr/bin/uwsgi /etc/contrail/contrail-api-uwsgi.ini"
else
  cmd="/usr/bin/contrail-api --conf_file /etc/contrail/contrail-api-0.conf --conf_file /etc/contrail/contrail-keystone-auth.conf --worker_id 0"
fi

exec $cmd
