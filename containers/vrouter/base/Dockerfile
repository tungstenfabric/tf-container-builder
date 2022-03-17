ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ENV NODE_TYPE=vrouter
LABEL $VENDOR_DOMAIN".pod"=$NODE_TYPE

# removing network-scripts: this folder will mounted from the host (or not used in Ubuntu) so the one installed by initscripts package in container is removed.
RUN \
    source /etc/os-release && \
    pkgs='NetworkManager initscripts ethtool pciutils sudo contrail-vrouter-utils' && \
    if [[ "$ID" == 'rhel' && "${PLATFORM_ID//*:/}" == 'el8' ]] ; then \
        pkgs="network-scripts net-tools $pkgs" ; \
    fi && \
    yum install -y $pkgs && \
    yum clean all -y && \
    if [[ "$ID" == 'rhel' && "${PLATFORM_ID//*:/}" == 'el8' ]] ; then \
        rm -f /usr/sbin/ifup /usr/sbin/ifdown && \
        cp /etc/sysconfig/network-scripts/ifup /etc/sysconfig/network-scripts/ifdown /usr/sbin/ ; \
    fi && \
    mkdir -p /opt/contrail && \
    cp -r /etc/sysconfig/network-scripts /opt/contrail/ && \
    rm -rf /var/cache/yum /etc/sysconfig/network-scripts && \
    ldconfig

COPY *.sh ifup-* ifdown-* network-functions-vrouter* dhclient-vhost0.conf /

CMD ["/usr/bin/tail","-f","/dev/null"]
