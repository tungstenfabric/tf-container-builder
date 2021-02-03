ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV NODE_TYPE=vcenter-manager \
    SERVICE_NAME=manager
LABEL name=$CONTAINER_NAME \
      summary="vSphereESX Agent Manager" \
      description="VMware provides a standard vCenter solution called vSphereESX Agent Manager (EAM), that allows you to deploy, monitor, and manage ContrailVMs on ESXi hosts." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN  yum install -y contrail-vcenter-manager && \
     yum clean all -y && \
     rm -rf /var/cache/yum

COPY *.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/contrail-vcenter-manager"]
