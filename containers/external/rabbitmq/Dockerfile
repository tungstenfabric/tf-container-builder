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
    source /functions.sh && \
    source /etc/os-release && \
    ver=$(echo $VERSION_ID | cut -d '.' -f 1) && \
    if [[ ${ver} == 8 ]]; then \
        RABBITMQ_VERSION="3.10.7" && \
        ERLANG_VERSION="25.0.4"; \
    else \
        RABBITMQ_VERSION="3.7.28" && \
        ERLANG_VERSION="21.3.8.21"; \
    fi && \
    download_package https://packagecloud.io rabbitmq/erlang/packages/el/${ver}/erlang-${ERLANG_VERSION}-1.el${ver}.x86_64.rpm/download.rpm erlang.rpm && \
    download_package https://packagecloud.io rabbitmq/rabbitmq-server/packages/el/${ver}/rabbitmq-server-${RABBITMQ_VERSION}-1.el${ver}.noarch.rpm/download.rpm rabbitmq-server.rpm && \ 
    yum install -y erlang.rpm rabbitmq-server.rpm vim-common && \
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
