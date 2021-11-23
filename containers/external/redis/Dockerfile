ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV SERVICE_NAME=redis \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Redis" \
      description="Contrail Redis server supports query engine." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

COPY *.sh /

RUN \
    REDIS_RPM_NAME=redis-6.0.15-1.el7.remi.x86_64 && \
    set -ex && for item in `ls /__*` ; do mv $item /${item:3} ; done && \
    source /functions.sh && \
    download_package https://github.com tungstenfabric/tf-third-party-cache/blob/master/redis/${REDIS_RPM_NAME}.rpm?raw=true ${REDIS_RPM_NAME}.rpm && \
    yum install ${REDIS_RPM_NAME}.rpm -y && \
    usermod -a -G $CONTRAIL_GID redis && \
    rm -rf ${REDIS_RPM_NAME}.rpm && \
    yum clean all -y && rm -rf /var/cache/yum

RUN mkdir /data && chown redis:redis /data
VOLUME /data
WORKDIR /data

ENTRYPOINT ["/contrail-entrypoint.sh"]

EXPOSE 6379

CMD ["redis-server"]
