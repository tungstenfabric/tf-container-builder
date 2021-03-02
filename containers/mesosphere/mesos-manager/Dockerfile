ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV NODE_TYPE=mesosphere \
    SERVICE_NAME=mesos-manager \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Mesosphere Manager" \
      description="Contrail Mesosphere Manager." \
      $VENDOR_DOMAIN".pod"=$NODE_TYPE \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN yum install -y contrail-mesos-manager && \
    yum clean all -y && \
    rm -rf /var/cache/yum

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/contrail-mesos-manager", "-c", "/etc/contrail/contrail-mesos.conf"]
