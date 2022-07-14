ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV SERVICE_NAME=kafka \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Kafka" \
      description="Contrail Kafka is used for streaming data in Analytics DB." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

ENV KAFKA_DIR=/opt/kafka \
    KAFKA_CONF_DIR=/opt/kafka/config \
    LOG_DIR=/var/log/kafka \
    KAFKA_OPTS="-XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=100M" \
    KAFKA_USER=kafka \
    KAFKA_GROUP=kafka

COPY *.sh /

RUN \
    KAFKA_DISTRO_NAME="kafka_2.12-2.6.3" && \
    for item in `ls /__*` ; do mv $item /${item:3} ; done && \
    yum install -y java java-1.8.0-openjdk python3 openssl && \
    source /functions.sh && \
    download_package https://archive.apache.org dist/kafka/2.6.3/$KAFKA_DISTRO_NAME.tgz $KAFKA_DISTRO_NAME.tgz --no-check-certificate && \
    tar -xvf $KAFKA_DISTRO_NAME.tgz && \
    mkdir -p $KAFKA_CONF_DIR $LOG_DIR && \
    mv $KAFKA_DISTRO_NAME/* $KAFKA_DIR && \
    rm -f $KAFKA_DISTRO_NAME.tgz && \
    yum clean all -y && \
    rm -rf /var/cache/yum && \
    groupadd -f -g 1011 kafka && adduser -M -g kafka kafka && \
    usermod -a -G $CONTRAIL_GID $KAFKA_USER && \
    chown -R $KAFKA_USER:$KAFKA_GROUP $LOG_DIR $KAFKA_DIR

ENTRYPOINT ["/docker-entrypoint.sh"]
WORKDIR $KAFKA_DIR
CMD ["bin/kafka-server-start.sh", "config/server.properties"]
