#!/bin/bash -e

source /common.sh

cp /etc/cassandra-reaper/cassandra-reaper.origin /etc/cassandra-reaper/cassandra-reaper.yaml
chmod 666 /var/log/cassandra-reaper/reaper.log

# edit cassandra-reaper config
REAPER_CONFIG=${CASSANDRA_REAPER_CONFIG}/cassandra-reaper.yaml
sed -i "s/port: 8080/port: ${CASSANDRA_REAPER_APP_PORT}/g" ${REAPER_CONFIG}
sed -i "s/port: 8081/port: ${CASSANDRA_REAPER_ADM_PORT}/g" ${REAPER_CONFIG}
sed -i "s/level: INFO/level: DEBUG/g" ${REAPER_CONFIG}
sed -i 's%classpath:shiro.ini%file:/etc/cassandra-reaper/configs/shiro.ini%g' ${REAPER_CONFIG}

  cat <<EOF >>${REAPER_CONFIG}
jmxAuth:
  username: ${CASSANDRA_REAPER_JMX_AUTH_USERNAME}
  password: ${CASSANDRA_REAPER_JMX_AUTH_PASSWORD}

jmxmp:
  enabled: false
  ssl: false

cryptograph:
  type: symmetric
  systemPropertySecret: CASSANDRA_REAPER_JMX_KEY

autoScheduling:
  enabled: true
  initialDelayPeriod: PT15S
  periodBetweenPolls: PT10M
  timeBeforeFirstSchedule: PT5M
  scheduleSpreadPeriod: PT6H

storageType: cassandra
cassandra:
  clusterName: "${CASSANDRA_CLUSTER_NAME}"
  port: ${CASSANDRA_CQL_PORT}
  contactPoints: ["$CASSANDRA_CONNECT_POINTS"]
  keyspace: reaper_db
  authProvider:
    type: plainText
    username: ${CASSANDRA_REAPER_JMX_AUTH_USERNAME}
    password: ${CASSANDRA_REAPER_JMX_AUTH_PASSWORD}
EOF

cat <<EOF >/etc/cassandra-reaper/configs/shiro.ini
[main]
authc = org.apache.shiro.web.filter.authc.PassThruAuthenticationFilter
authc.loginUrl = /webui/login.html

# Java Web Token authentication for REST endpoints
jwtv = io.cassandrareaper.resources.auth.ShiroJwtVerifyingFilter
rest = io.cassandrareaper.resources.auth.RestPermissionsFilter

# Disable global filters introduced in Shiro 1.6.0 as they break our redirects.
filterChainResolver.globalFilters = null

[roles]
operator = *
user = *:read

[urls]
# Web UI requires manual authentication and session cookie
/webui/ = authc
/webui = authc
/jwt = authc
/webui/*.html* = authc

# login page and all js and css resources do not require authentication
/webui/login.html = anon
/webui/** = anon
/ping = anon
/login = anon


# REST endpoints require a Java Web Token and uses the HttpMethodPermissionFilter for http method level permissions
/cluster/** = noSessionCreation,jwtv,rest[cluster]
/repair_schedule/** = noSessionCreation,jwtv,rest[repair_schedule]
/repair_run/** = noSessionCreation,jwtv,rest[repair_run]
/snapshot/** = noSessionCreation,jwtv,rest[snapshot]
/** = noSessionCreation,jwtv


#  custom authentication will be appended
[users]
${CASSANDRA_REAPER_JMX_AUTH_USERNAME} = ${CASSANDRA_REAPER_JMX_AUTH_PASSWORD}, operator
EOF


if is_enabled $CASSANDRA_SSL_ENABLE ; then
  cat <<EOF >>${REAPER_CONFIG}
  ssl:
    type: jdk
EOF

  jks_dir=${JKS_DIR:-'/usr/local/lib/cassandra/conf'}
  cat <<EOF >/etc/cassandra-reaper/cassandra-reaper-ssl.properties
-Dssl.enable=true
-Djavax.net.ssl.keyStore=${jks_dir}/server-keystore.jks
-Djavax.net.ssl.keyStorePassword=${CASSANDRA_SSL_KEYSTORE_PASSWORD}
-Djavax.net.ssl.trustStore=${jks_dir}/server-truststore.jks
-Djavax.net.ssl.trustStorePassword=${CASSANDRA_SSL_TRUSTSTORE_PASSWORD}
EOF

SSL_OPT="--ssl"
fi

# wait until cqlsh will be available
while ! cqlsh $CASSANDRA_LISTEN_ADDRESS $CASSANDRA_CQL_PORT $SSL_OPT -e "CREATE KEYSPACE IF NOT EXISTS reaper_db WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter1': $CASSANDRA_COUNT};" ; do
    sleep 5
done

# run reaper service
export CASSANDRA_REAPER_JMX_KEY
run_service cassandra-reaper &

# add cluster
reaper_url="http://$CASSANDRA_LISTEN_ADDRESS:${CASSANDRA_REAPER_APP_PORT}"
# wait until up
while ! curl $reaper_url/webui/login.html >/dev/null ; do
  sleep 5
done
jsessionid=$(curl -v  -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "username=${CASSANDRA_REAPER_JMX_AUTH_USERNAME}&password=${CASSANDRA_REAPER_JMX_AUTH_PASSWORD}" "${reaper_url}/login" 2>&1 | awk -F': ' '/JSESSIONID/ { print $2 }' | tr -d '\r')
curl --cookie "$jsessionid" -H "Content-Type: application/json" -X POST "${reaper_url}/cluster?seedHost=$CASSANDRA_LISTEN_ADDRESS&jmxPort=${CASSANDRA_JMX_LOCAL_PORT}"
