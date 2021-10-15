ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV SERVICE_NAME=rabbitmq \
    RABBITMQ_LOGS=- \
    RABBITMQ_SASL_LOGS=- \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail RabbitMQ" \
      description="Contrail Rabbitmq is the message bus that different Contrail processes subscribe to." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

COPY *.sh /

# vim-common is needed because of xxd tool
RUN /bin/bash -c 'for item in `ls /__*` ; do mv $item /${item:3} ; done' && \
    wget -nv -t3 -O erlang-21.3.8.21-1.el7.x86_64.rpm  ${SITE_MIRROR:-"https://packagecloud.io"}/rabbitmq/erlang/packages/el/7/erlang-21.3.8.21-1.el7.x86_64.rpm/download.rpm && \
    wget -nv -t3 -O rabbitmq-server-3.7.20-1.el7.noarch.rpm ${SITE_MIRROR:-"https://packagecloud.io"}/rabbitmq/rabbitmq-server/packages/el/7/rabbitmq-server-3.7.20-1.el7.noarch.rpm/download.rpm && \
    yum install -y erlang-21.3.8.21-1.el7.x86_64.rpm rabbitmq-server-3.7.20-1.el7.noarch.rpm vim-common && \
    usermod -a -G $CONTRAIL_GID rabbitmq && \
    usermod -d /var/lib/rabbitmq rabbitmq && \
    rabbitmq-plugins enable --offline rabbitmq_management && \
    rm -f *rpm && \
    yum clean all -y && \
    rm -rf /var/cache/yum

VOLUME "/var/lib/rabbitmq"

EXPOSE 15671 15672 4369 5671 5672 25672

ENTRYPOINT ["/contrail-entrypoint.sh"]

CMD ["rabbitmq-server"]
