ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-controller-config-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=device-manager \
    CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="Contrail Device Manager" \
      description="Contrail Device Manager is used to manage network devices in the Contrail system." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

# git rpm cannot be remove as it removes contrail-utils, and common by deps
RUN pip install --no-compile \
        "markdown==3.1.1" \
        "markupSafe==1.1.1" \
        "ansible==2.6.13" \
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
    ansible-galaxy install Juniper.junos,2.4.2 && \
    yum clean all -y && \
    rm -rf /var/cache/yum

COPY *.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/contrail-device-manager", "--conf_file", "/etc/contrail/contrail-device-manager.conf", "--conf_file", "/etc/contrail/contrail-keystone-auth.conf"]
