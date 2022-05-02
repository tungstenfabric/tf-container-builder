ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-controller-config-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV SERVICE_NAME=device-manager \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Device Manager" \
      description="Contrail Device Manager is used to manage network devices in the Contrail system." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

# git rpm cannot be remove as it removes contrail-utils, and common by deps
# use direct download to be able to download from cache instead of `ansible-galaxy install Juniper.junos,2.4.2`
RUN python2 -m pip install --no-compile \
        "markdown==3.1.1" \
        "markupSafe==1.1.1" \
        "ansible==2.8.2" \
        "colorama==0.4.3" \
        "configparser==4.0.2" \
        "icdiff==1.9.1" \
        "inflection==0.3.1" \
        "jinja2==2.11.1" \
        "jsnapy==1.3.2" \
        "junos-eznc==2.5.3" \
        "jxmlease==1.0.1" \
        "lxml==4.5.0" \
        "ncclient==0.6.3" \
        "pyserial==3.4" \
        "python-jsonschema-objects==0.3.12" \
        "scp==0.13.2" \
        "selectors2==2.0.1" \
        "timeout-decorator==0.4.1" && \
    yum install -y git iputils && \
    yum clean all -y && \
    rm -rf /var/cache/yum && \
    source /functions.sh && \
    download_package https://github.com Juniper/ansible-junos-stdlib/archive/2.4.2.tar.gz Juniper.junos && \
    ansible-galaxy install Juniper.junos && \
    rm -f Juniper.junos

COPY *.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/contrail-device-manager", "--conf_file", "/etc/contrail/contrail-device-manager.conf", "--conf_file", "/etc/contrail/contrail-keystone-auth.conf"]
