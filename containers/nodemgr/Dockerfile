ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=nodemgr \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Node Manager" \
      description="Contrail Node Manager is a monitor process per contrail virtual node that tracks the running state of the processes." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

# for building from rpms
# install chrony, ntp and iputils-clockdiff to enable checking time sync by nodemgr
RUN   \
      source /functions.sh && \
      python2 -m pip install --no-compile --no-binary=protobuf "docker==2.4.2" "grpcio==1.29.0" "protobuf==3.17.3" "containerd==1.5.2" && \
      yum install -y contrail-nodemgr python3-contrail chrony podman && \
      CONTAINERD_RPM_NAME=containerd.io-1.4.12-3.1.el7.x86_64.rpm && \
      download_package https://download.docker.com linux/centos/7/x86_64/stable/Packages/${CONTAINERD_RPM_NAME} ${CONTAINERD_RPM_NAME} && \
      rpm -Uvh --nodeps --replacepkgs ${CONTAINERD_RPM_NAME} && \
      yum clean all -y && \
      rm -rf /var/cache/yum

COPY *.sh /
ENTRYPOINT ["/entrypoint.sh"]
# use shell form for CMD as shell variables processing is required here
CMD /usr/bin/contrail-nodemgr --nodetype=${NODEMGR_TYPE}
