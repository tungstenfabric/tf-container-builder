ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV SERVICE_NAME=cassandra \
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
    CASSANDRA_UID=2000 \
    CASSANDRA_GID=2000 \
    PATH="/opt/cassandra/bin:$PATH"

COPY *.sh /

# TODO: pin jdk version
# https://issues.apache.org/jira/projects/CASSANDRA/issues/CASSANDRA-17581?filter=allissues
# (it can be unpinned after cassandra be upgraded >= 3.11.13)
RUN \
    CASSANDRA_VERSION=3.11.3 && \
    set -ex && for item in `ls /__*` ; do mv $item /${item:3} ; done && \
    yum install -y numactl which jemalloc && \
    yum install -y --exclude="*slowdebug*" --exclude="*fastdebug*" "java-1.8.0-openjdk < 1:1.8.0_332" && \
    groupadd -f -g ${CASSANDRA_GID} ${CASSANDRA_GROUP} && adduser -u ${CASSANDRA_UID} -M -g ${CASSANDRA_GROUP} ${CASSANDRA_USER} && \
    usermod -a -G $CONTRAIL_GID ${CASSANDRA_USER} && \
    source /functions.sh && \
    download_package https://archive.apache.org dist/cassandra/$CASSANDRA_VERSION/apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz && \
    mkdir -p ${CASSANDRA_HOME} && \
    tar -xzf apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz -C ${CASSANDRA_HOME} --strip-components 1 && \
    rm -rf  apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz && \
    mv "$CASSANDRA_HOME/conf" $CASSANDRA_CONFIG && \
    ln -sT "$CASSANDRA_CONFIG" "$CASSANDRA_HOME/conf" && \
    mkdir -p ${CASSANDRA_LIB} ${CASSANDRA_LOG} && \
    chown -R ${CASSANDRA_USER}:${CASSANDRA_GROUP} ${CASSANDRA_CONFIG} ${CASSANDRA_LOG} ${CASSANDRA_LIB} && \
    ln -sT ${CASSANDRA_LIB} "${CASSANDRA_HOME}/data" && \
    ln -sT ${CASSANDRA_LOG} "${CASSANDRA_HOME}/logs" && \
    rm -f /opt/cassandra/lib/libthrift-* && \
    download_package https://github.com tungstenfabric/tf-third-party-cache/blob/master/libthrift/libthrift-0.13.0.jar?raw=true /opt/cassandra/lib/libthrift-0.13.0.jar && \
    rm -f /opt/cassandra/lib/netty-all-* && \
    download_package https://repo1.maven.org maven2/io/netty/netty-all/4.1.39.Final/netty-all-4.1.39.Final.jar /opt/cassandra/lib/netty-all-4.1.39.Final.jar && \
    rm -f /opt/cassandra/lib/logback-* && \
    download_package https://repo1.maven.org maven2/ch/qos/logback/logback-classic/1.2.9/logback-classic-1.2.9.jar /opt/cassandra/lib/logback-classic-1.2.9.jar && \
    download_package https://repo1.maven.org maven2/ch/qos/logback/logback-core/1.2.9/logback-core-1.2.9.jar /opt/cassandra/lib/logback-core-1.2.9.jar && \
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
