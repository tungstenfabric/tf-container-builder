ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Mellanox plugin for RedHat" \
      description="DPDK Mellanox kernel module for RedHat." \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN yum update -y && \
    yum install -y mstflint pciutils && \
    yum clean all -y && \
    rm -rf /var/cache/yum

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
