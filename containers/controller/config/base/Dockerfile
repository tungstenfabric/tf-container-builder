ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ENV NODE_TYPE=config
LABEL $VENDOR_DOMAIN".pod"=$NODE_TYPE

# gcc, etc - are for gevent build
RUN sed -e '/^tsflags=nodocs/d' -i /etc/yum.conf && \
    yum install -y contrail-config contrail-config-openstack && \
    yum clean all -y && \
    rm -rf /var/cache/yum

CMD ["/usr/bin/tail","-f","/dev/null"]
