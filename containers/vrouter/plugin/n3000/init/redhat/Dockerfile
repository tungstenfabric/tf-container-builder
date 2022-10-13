ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-vrouter-base:${CONTRAIL_CONTAINER_TAG}

ARG LINUX_DISTR
ARG CONTAINER_NAME
ENV CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME                                                   \
      summary="N3K plugin for RedHat"                                        \
      description="N3K inititialization container for RedHat."               \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

SHELL ["/bin/bash", "-c"]

RUN yes | python3 -m pip install intelhex || true                          && \
    yum install -y contrail-vrouter-dpdk-n3000-tools pciutils dhclient     && \
    rpm -Uvh --nodeps $(repoquery -q --location opae-libs)                 && \
    rpm -Uvh --nodeps $(repoquery -q --location opae-devel)                && \
    rpm -Uvh --nodeps $(repoquery -q --location opae.admin)                && \
    rpm -Uvh --nodeps $(repoquery -q --location opae-tools)                && \
    rpm -Uvh --nodeps $(repoquery -q --location opae-tools-extra)          && \
    rpm -Uvh --nodeps $(repoquery -q --location opae.pac_sign)             && \
    rpm -Uvh --nodeps $(repoquery -q --location opae-super-rsu-n3000)      && \
    mkdir -p /opt/opae                                                     && \
    yumdownloader --destdir=/opt/opae/ opae-intel-fpga-driver              && \
    mkdir -p /opt/n3000/site_packages                                      && \
    cp -r /usr/lib/python2.7/site-packages/opae* /opt/n3000/site_packages/ && \
    mv /usr/bin/fecmode /opt/n3000/fecmode                                 && \
    mv /usr/bin/rsu /opt/n3000/rsu                                         && \
    yum clean all -y                                                       && \
    rm -rf /var/cache/yum

COPY entrypoint.sh /
COPY n3000-* /

ENTRYPOINT ["/entrypoint.sh"]
