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
RUN \
    source /functions.sh && \
    download_package https://downloadmirror.intel.com 30590/eng/800%20series%20comms%20binary%20package%201.3.30.0.zip /usr/tmp/downloaded_ice_comms-1.3.30.0.zip && \
    cd /usr/tmp && \
    yum -y install unzip && \
    unzip -o -d /usr/tmp downloaded_ice_comms-1.3.30.0.zip && \
    unzip -o -d /usr/tmp/ice-1.3.30.0 ice_comms-1.3.30.0.zip && \
    mkdir -p /lib/firmware/updates/intel/ice/ddp && \
    cp /usr/tmp/ice-1.3.30.0/ice_comms-1.3.30.0.pkg /lib/firmware/updates/intel/ice/ddp/ && \
    cp /usr/tmp/ice-1.3.30.0/ice.pkg /lib/firmware/updates/intel/ice/ddp/ && \
    cd /lib/firmware/updates/intel/ice/ddp && \
    ln -sf ice_comms-1.3.30.0.pkg ice.pkg && \
    rm -rf /usr/tmp/*ice*

RUN yum install -y dhclient NetworkManager contrail-vrouter-dpdk && \
    yum clean all -y && \
    rm -rf /var/cache/yum /etc/sysconfig/network-scripts && \
    ldconfig

COPY entrypoint.sh /
COPY *_defs /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/contrail-vrouter-dpdk"]
