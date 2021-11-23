ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Kubernetes Container Network Interface" \
      description="Contrail provides support for Container Network Interface for Kubernetes." \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN \
    source /functions.sh && \
    download_package https://github.com containernetworking/cni/releases/download/v0.3.0/cni-v0.3.0.tgz /opt/cni-v0.3.0.tgz && \
    yum install -y contrail-k8s-cni && \
    yum clean all -y && \
    rm -rf /var/cache/yum

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]

