ARG CONTRAIL_REGISTRY
ARG CONTRAIL_CONTAINER_TAG
FROM ${CONTRAIL_REGISTRY}/contrail-base:${CONTRAIL_CONTAINER_TAG}

ARG SITE_MIRROR
ARG CONTAINER_NAME
ENV CONTAINER_NAME=$CONTAINER_NAME
LABEL name=$CONTAINER_NAME \
      summary="A common tool for debugging" \
      description="The image contains scripts to debug Contrail processes." \
      $VENDOR_DOMAIN".container.name"=$CONTAINER_NAME

# tshark is needed for sandump tool which is included into contrail-tools package
RUN \
      source /etc/os-release && \
      pkgs='sudo openssh-clients bzip2 contrail-tools contrail-vrouter-dpdk-tools' && \
      if [[ "$ID" != 'rhel' || "${PLATFORM_ID//*:/}" == 'el8' ]] ; then \
            pkgs+=' python-paramiko python-yaml python-crypto' ; \
      else \
            python2 -m pip install --no-compile crypto paramiko "PyYAML>=5.1" ; \
      fi && \
      yum install -y $pkgs && \
      yum clean all -y && \
      rm -rf /var/cache/yum && \
      wget -nv -c --tries=3 -O /tmp/tshark3_2.tar.bz2 ${SITE_MIRROR:-"https://github.com"}/tungstenfabric/tf-third-party-cache/raw/master/tshark/tshark3_2.tar.bz2 && \
      tar --skip-old-files -xvf /tmp/tshark3_2.tar.bz2 && \
      if [ ! -e /lib64/libssh.so.4 ] ; then ln -s /lib64/libssh.so.4.4.0 /lib64/libssh.so.4 ; fi && \
      if [ ! -e /lib64/libwsutil.so.11 ] ; then ln -s /lib64/libwsutil.so.11.0.0 /lib64/libwsutil.so.11 ; fi && \
      if [ ! -e /lib64/libbrotlicommon.so.1 ] ; then ln -s /lib64/libbrotlicommon.so.1.0.7 /lib64/libbrotlicommon.so.1 ; fi && \
      if [ ! -e /lib64/libwiretap.so.10 ] ; then ln -s /lib64/libwiretap.so.10.0.2 /lib64/libwiretap.so.10 ; fi && \
      if [ ! -e /lib64/libsnappy.so.1 ] ; then ln -s /lib64/libsnappy.so.1.1.4 /lib64/libsnappy.so.1 ; fi && \
      if [ ! -e /lib64/libzstd.so.1 ] ; then ln -s /lib64/libzstd.so.1.4.5 /lib64/libzstd.so.1 ; fi && \
      if [ ! -e /lib64/libnghttp2.so.14 ] ; then ln -s /lib64/libnghttp2.so.14.16.1 /lib64/libnghttp2.so.14 ; fi && \
      if [ ! -e /lib64/libwireshark.so.13 ] ; then ln -s /lib64/libwireshark.so.13.0.2 /lib64/libwireshark.so.13 ; fi && \
      if [ ! -e /lib64/libbrotlidec.so.1 ] ; then ln -s /lib64/libbrotlidec.so.1.0.7 /lib64/libbrotlidec.so.1 ; fi

ENV PS1="\033[1m($CONTAINER_NAME)\033[m\017[$(id -un)@$(hostname -s) $(pwd)]$ "

ENTRYPOINT ["/bin/bash"]
