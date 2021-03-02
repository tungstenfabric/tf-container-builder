ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-analytics-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=snmp-collector \
    NODE_TYPE=analytics-snmp \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="TungstenFabric SNMP Collector" \
      description="TungstenFabric SNMP Collector collects data from switches(Spine/Leaf)." \
      $VENDOR_DOMAIN".pod"=$NODE_TYPE \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/tf-snmp-collector", "-c", "/etc/contrail/tf-snmp-collector.conf", "--device-config-file", "/etc/contrail/device.ini"]
