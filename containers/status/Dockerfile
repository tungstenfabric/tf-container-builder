ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Container with code of contrail-status tool" \
      description="Display a list of all components of a Contrail server node and report their current status of active or inactive." \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN \
    source /functions.sh && \
    yum install -y podman contrail-nodemgr && \
    CONTAINERD_RPM_NAME=containerd.io-1.6.7-3.1.el7.x86_64.rpm && \
    download_package https://download.docker.com linux/centos/7/x86_64/stable/Packages/${CONTAINERD_RPM_NAME} ${CONTAINERD_RPM_NAME} && \
    rpm -Uvh --nodeps --replacepkgs ${CONTAINERD_RPM_NAME} && \
    rm -f ${CONTAINERD_RPM_NAME} && \
    yum clean all -y && \
    rm -rf /var/cache/yum && \
    python2 -m pip install --no-compile --no-binary=protobuf "docker==2.4.2" "grpcio==1.29.0" "protobuf==3.17.3" "containerd==1.5.2"

COPY contrail-status.py /root
COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]

ENV PS1="\033[1m($CONTAINER_NAME)\033[m\017[$(id -un)@$(hostname -s) $(pwd)]$ "
