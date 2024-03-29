ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Init container for OpenStack neutron-server" \
      description="Sidecar container with libraries for neutron-server." \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

COPY *.sh /

# run _prepare_packages.sh as a last step cause it can break some repositories
RUN \
    mkdir -p /opt/contrail/site-packages /opt/contrail_python3/site-packages && \
    python2 -m pip install --no-compile --target=/opt/contrail/site-packages future && \
    python3 -m pip install --no-compile --target=/opt/contrail_python3/site-packages "future==0.18.2" && \
    rpm -Uvh --nodeps $(repoquery -q --location python-contrail) && \
    rpm -Uvh --nodeps $(repoquery -q --location neutron-plugin-contrail) && \
    cp -rf /usr/lib/python2.7/site-packages/neutron_plugin_contrail* /opt/contrail/site-packages && \
    cp -rf /usr/lib/python2.7/site-packages/vnc_api* /opt/contrail/site-packages && \
    cp -rf /usr/lib/python2.7/site-packages/cfgm_common* /opt/contrail/site-packages && \
    cp -rf /usr/lib/python2.7/site-packages/neutron_plugin_contrail* /opt/contrail_python3/site-packages && \
    cp -rf /usr/lib/python2.7/site-packages/vnc_api* /opt/contrail_python3/site-packages && \
    cp -rf /usr/lib/python2.7/site-packages/cfgm_common* /opt/contrail_python3/site-packages && \
    yum autoremove -y python-contrail neutron-plugin-contrail && \
    yum clean all -y && \
    rm -rf /var/cache/yum && \
    /_prepare_packages.sh && rm -f /_prepare_packages.sh

ENTRYPOINT ["/entrypoint.sh"]
