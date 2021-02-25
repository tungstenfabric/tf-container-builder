ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-controller-config-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=api \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Controller Configuration API" \
      description="Controller Configuration API provides a REST API to an orchestration system." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

# contrail-config-openstack contains svc_monitor and vnc_openstack modules
RUN yum install -y python-neutron-lib && \
    yum clean all -y && \
    rm -rf /var/cache/yum

COPY *.sh /

ENTRYPOINT ["/entrypoint.sh"]
