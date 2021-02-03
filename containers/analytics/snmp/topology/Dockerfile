ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-analytics-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=topology \
    NODE_TYPE=analytics-snmp
LABEL name=$CONTAINER_NAME \
      summary="TungstenFabric SNMP Topology" \
      description="TungstenFabric SNMP Topology periodically updates topology table, which is used by UI to draw maps." \
      $VENDOR_DOMAIN".pod"=$NODE_TYPE \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/tf-topology", "-c", "/etc/contrail/tf-topology.conf"]
