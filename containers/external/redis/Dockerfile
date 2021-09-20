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

ARG REDIS_RPM_NAME=redis-6.0.15-1.el7.remi.x86_64
ARG REDIS_CACHE=${SITE_MIRROR:-'https://github.com'}/tungstenfabric/tf-third-party-cache/blob/master/redis

COPY *.sh /

RUN set -eux && for item in `ls /__*` ; do mv $item /${item:3} ; done && \
    wget -nv --tries=3 -c -O ${REDIS_RPM_NAME}.rpm ${REDIS_CACHE}/${REDIS_RPM_NAME}.rpm?raw=true && \
    yum install python3 ${REDIS_RPM_NAME}.rpm -y && \
    usermod -a -G $CONTRAIL_GID redis && \
    rm -rf ${REDIS_RPM_NAME}.rpm && \
    yum clean all -y && rm -rf /var/cache/yum

RUN mkdir /data && chown redis:redis /data
VOLUME /data
WORKDIR /data

ENTRYPOINT ["/contrail-entrypoint.sh"]

EXPOSE 6379

CMD ["redis-server"]
