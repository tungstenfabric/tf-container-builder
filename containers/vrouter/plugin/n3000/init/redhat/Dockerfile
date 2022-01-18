ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG LINUX_DISTR
ARG CONTAINER_NAME
ENV CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME                                                   \
      summary="N3K plugin for RedHat"                                        \
      description="N3K inititialization container for RedHat."               \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

SHELL ["/bin/bash", "-c"]

RUN yes | python3 -m pip install intelhex || true                          && \
    yum install -y contrail-vrouter-dpdk-n3000-tools                       && \
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
    cp /usr/bin/fecmode /opt/n3000/fecmode                                 && \
    cp /usr/bin/rsu /opt/n3000/rsu                                         && \
    yum autoremove -y opae*                                                && \
    yum clean all -y                                                       && \
    rm -rf /var/cache/yum

COPY entrypoint.sh /
COPY n3000-driver-mgmt.sh /
COPY n3000-offload-config.sh /
COPY n3000-init.sh /
COPY n3000-fw-manager.sh /
COPY n3000_defs /
COPY n3000-env.sh /
COPY n3000-int-restore.sh /

ENTRYPOINT ["/entrypoint.sh"]
