ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-vrouter-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=agent-dpdk \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail DPDK poll mode driver" \
      description="DPDK support for Contrail vrouter agent" \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN yum install -y dhclient NetworkManager contrail-vrouter-dpdk && \
    yum clean all -y && \
    rm -rf /var/cache/yum /etc/sysconfig/network-scripts && \
    ldconfig

COPY entrypoint.sh /
COPY *_defs /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/contrail-vrouter-dpdk"]
