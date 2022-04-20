ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail general base image" \
      description="The image contains debug symbols for build and may be used to debug Contrail processes." \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

# TODO: debug packages are unavailable in CI jobs, ignore errors
RUN \
    yum install -y contrail-debuginfo || true && \
    yum install -y contrail-vrouter-dpdk-debuginfo || true && \
    yum install -y contrail-manifest && \
    yum clean all -y && \
    rm -rf /var/cache/yum && \
    ln -s /opt/contrail/manifest.xml /manifest.xml

ENV PS1="\033[1m($CONTAINER_NAME)\033[m\017[$(id -un)@$(hostname -s) $(pwd)]$ "
