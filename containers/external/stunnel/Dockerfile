ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=stunnel
LABEL name=$CONTAINER_NAME \
      summary="Contrail Stunnel" \
      description="Contrail Stunnel provides encryption to Redis" \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

COPY *.sh /
RUN /bin/bash -c 'for item in `ls /__*` ; do mv $item /${item:3} ; done' && \
    yum install -y python3 openssl stunnel && \
    yum clean all -y && \
    rm -rf /var/cache/yum

ENTRYPOINT ["/contrail-entrypoint.sh"]
CMD ["stunnel", "/etc/stunnel/stunnel.conf"]
