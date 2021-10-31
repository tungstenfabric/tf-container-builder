ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-vrouter-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Kernel init container for vrouter" \
      description="Prepares the host operating system for the contrail vrouter kernel interface." \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN rpm -Uvh --nodeps $(repoquery -q --location contrail-vrouter) && \
    yum clean all -y && \
    rm -rf /var/cache/yum

COPY *.sh /

ENTRYPOINT ["/entrypoint.sh"]
