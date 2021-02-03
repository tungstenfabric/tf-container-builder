ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-vrouter-base:${CONTRAIL_CONTAINER_TAG}

ARG CONTAINER_NAME
ENV SERVICE_NAME=agent
LABEL name=$CONTAINER_NAME \
      summary="Contrail Vrouter Agent" \
      description="The vRouter agent is a user space process running inside Linux. It acts as the local, lightweight control plane." \
      $VENDOR_DOMAIN".service"=$SERVICE_NAME \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

RUN  yum install -y dhclient NetworkManager contrail-vrouter-agent haproxy libvirt-client \
     python-opencontrail-vrouter-netns python-contrail-vrouter-api && \
     rpm -qi contrail-vrouter-agent | awk '/Version/{print($3)}' > /contrail_build_version && \
     yum clean all -y && \
     rm -rf /var/cache/yum /etc/sysconfig/network-scripts && \
     ldconfig

COPY *.sh /
# /etc/dhcp/dhclient-script is allowed by apparmor to execute
COPY vhost0-dhcp/dhclient-script /etc/dhcp/dhclient-script
COPY vhost0-dhcp/vhost0-nameservers.sh /etc/dhcp/dhclient-exit-hooks.d/

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/contrail-vrouter-agent"]
