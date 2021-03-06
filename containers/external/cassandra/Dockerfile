ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV CONTRAIL_VERSION=$CONTRAIL_CONTAINER_TAG \
    SERVICE_NAME=cassandra \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Cassandra DB" \
      description="Configuration database for Contrail Controller." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

ENV CASSANDRA_HOME=/opt/cassandra \
    CASSANDRA_CONFIG=/etc/cassandra \
    CASSANDRA_LIB=/var/lib/cassandra \
    CASSANDRA_LOG=/var/log/cassandra \
    CASSANDRA_USER=cassandra \
    CASSANDRA_GROUP=cassandra \
    PATH="/opt/cassandra/bin:$PATH"

ARG CASSANDRA_VERSION=3.11.3
ARG DIST_URL="${SITE_MIRROR:-'https://archive.apache.org'}/dist/cassandra/$CASSANDRA_VERSION/apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz"

COPY *.sh /

RUN set -eux && for item in `ls /__*` ; do mv $item /${item:3} ; done && \
    yum install -y java java-1.8.0-openjdk numactl python3 openssl which jemalloc -y && \
    groupadd -f -g 999 ${CASSANDRA_GROUP} && adduser -u 999 -M -g ${CASSANDRA_GROUP} ${CASSANDRA_USER} && \
    usermod -a -G $CONTRAIL_GID ${CASSANDRA_USER} && \
    wget -nv --tries=3 -c $DIST_URL && \
    mkdir -p ${CASSANDRA_HOME} && \
    tar -xzf apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz -C ${CASSANDRA_HOME} --strip-components 1 && \
    rm -rf  apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz && \
    mv "$CASSANDRA_HOME/conf" $CASSANDRA_CONFIG && \
    ln -sT "$CASSANDRA_CONFIG" "$CASSANDRA_HOME/conf" && \
    mkdir -p ${CASSANDRA_LIB} ${CASSANDRA_LOG} && \
    chown -R ${CASSANDRA_USER}:${CASSANDRA_GROUP} ${CASSANDRA_CONFIG} ${CASSANDRA_LOG} ${CASSANDRA_LIB} && \
    ln -sT ${CASSANDRA_LIB} "${CASSANDRA_HOME}/data" && \
    ln -sT ${CASSANDRA_LOG} "${CASSANDRA_HOME}/logs" && \
    yum clean all -y && \
    rm -rf /var/cache/yum && \
# smoke test
	cassandra -v

VOLUME $CASSANDRA_LIB

ENTRYPOINT ["/contrail-entrypoint.sh"]
# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160

CMD ["cassandra", "-f"]
