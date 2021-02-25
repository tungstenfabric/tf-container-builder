ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=provisioner \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Provisioner" \
      description="Contrail Provisioner ia caoneiner that manage env for other containers." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

COPY *.sh /

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/tail","-f","/dev/null"]
