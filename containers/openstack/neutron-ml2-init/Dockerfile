ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-general-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Init container for OpenStack neutron-server with ml2 driver" \
      description="Sidecar container with libraries for neutron-server with ml2 driver." \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

COPY *.sh /

# run _prepare_packages.sh as a last step cause it can break some repositories
RUN wget -nv -c --tries=3 -O /tmp/get-pip.py https://bootstrap.pypa.io/2.7/get-pip.py && \
    python2 /tmp/get-pip.py 'pip==20.1' && \   
    mkdir -p /opt/contrail/site-packages && \
    pip install --no-compile --target=/opt/contrail/site-packages future && \
    rpm -Uvh --nodeps $(repoquery --location python-contrail) && \
    yum install -y git && \
    for i in {1..3} ; do \
        res=0 && \
        rm -rf networking-opencontrail && \
        git clone --depth=1 --single-branch -b stable/queens https://opendev.org/x/networking-opencontrail.git && \
        cd networking-opencontrail && \
        python setup.py install --root=/opt/contrail/ --no-compile && break ; \
        res=1 ; \
    done && \
    [[ "$res" == 0 ]] && \
    cp -rf /usr/lib/python2.7/site-packages/vnc_api* /opt/contrail/site-packages && \
    cp -rf /usr/lib/python2.7/site-packages/cfgm_common* /opt/contrail/site-packages && \
    yum autoremove -y git python-contrail tf-neutron-ml2-plugin && \
    yum clean all -y && \
    rm -rf networking-opencontrail /var/cache/yum

ENTRYPOINT ["/entrypoint.sh"]
