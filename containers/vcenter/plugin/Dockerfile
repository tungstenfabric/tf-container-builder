ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV NODE_TYPE=vcenter \
    SERVICE_NAME=plugin \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="VMware vCenter plugin" \
      description="VMware vCenter plugin workflows are represented as simple workflows in vRO plugin." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN   \
      yum install -y \
            java-1.8.0-openjdk \
            libcontrail-java-api libcontrail-vijava \
            libcontrail-vrouter-java-api contrail-vcenter-plugin && \
      yum clean all -y && \
      rm -rf /var/cache/yum && \
      ldconfig

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/contrail-vcenter-plugin"]
