# This is the general base for all: non-contrail specfic like external and for contrail specific

ARG LINUX_DISTR=centos
ARG LINUX_DISTR_VER=7.4.1708
FROM $LINUX_DISTR:$LINUX_DISTR_VER

ARG VENDOR_NAME
ARG VENDOR_DOMAIN
ARG CONTRAIL_CONTAINER_TAG

LABEL vendor=$VENDOR_NAME \
      version=$CONTRAIL_CONTAINER_TAG \
      release="5.1.0"

# Add required license as text file in Liceses directory
RUN mkdir /licenses
COPY licensing.txt /licenses

ARG GENERAL_EXTRA_RPMS=""
ARG YUM_ENABLE_REPOS=""
ARG LC_ALL="en_US.UTF-8"
ARG LANG="en_US.UTF-8"
ARG LANGUAGE="en_US.UTF-8"

# These definitions are just for build purposes and must not be changed at runtime
# CONTRAIL_VERSION - used by contrail-version tool
# LANG, LC_ALL - used by some tools, like rabbitmqctl
ENV VENDOR_DOMAIN=$VENDOR_DOMAIN \
    VENDOR_NAME=$VENDOR_NAME \
    CONTRAIL_GID=1999 \
    CONTRAIL_UID=1999 \
    CONTRAIL_USER=contrail \
    CONTRAIL_VERSION=$CONTRAIL_CONTAINER_TAG \
    LC_ALL=$LC_ALL \
    LANG=$LANG \
    LANGUAGE=$LANGUAGE

# this copy should be before yum install
COPY *.repo /etc/yum.repos.d/

RUN \
    source /etc/os-release && \
    echo "el${VERSION_ID//\.*/}" > /etc/yum/vars/tpcrelease && \
    YUM_ENABLE_REPOS=$(echo $YUM_ENABLE_REPOS | tr -d '"') && \
    if [[ -n "$YUM_ENABLE_REPOS" ]] ; then \
        echo "INFO: contrail-general-base: enable repos $YUM_ENABLE_REPOS" && \
        if ! type -p yum-config-manager ; then \
            yum install -y yum-utils ; \
        fi && \
        yum-config-manager --enable $YUM_ENABLE_REPOS && \
        yum clean metadata ; \
    fi && \
    yum update -y && \
    pkgs="hostname iproute less wget openssl" && \
    GENERAL_EXTRA_RPMS=$(echo $GENERAL_EXTRA_RPMS | tr -d '"' | tr ',' ' ') && \
    if [[ -n "$GENERAL_EXTRA_RPMS" ]] ; then \
        pkgs+=" $GENERAL_EXTRA_RPMS" ; \
    fi && \
    if [[ "$ID" == 'rhel' && "$VERSION_ID" == '8.4' ]] ; then \
        pkgs+=" python2 glibc-langpack-en compat-openssl10" ; \
    fi && \
    yum install -y $pkgs && \
    wget -nv -c --tries=3 -O /tmp/get-pip.py ${SITE_MIRROR:-"https://bootstrap.pypa.io"}/pip/2.7/get-pip.py && \
    python2 /tmp/get-pip.py 'pip==20.1' && \
    type -p pip || alternatives --verbose --install /usr/bin/pip pip $(type -p pip2) 100 && \
    type -p python || alternatives --verbose --set python /usr/bin/python2 && \
    yum install -y python3 python3-setuptools && \
    yum clean all -y && \
    rm -rf /var/cache/yum && \
    groupadd --gid $CONTRAIL_GID --system $CONTRAIL_USER && \
    useradd -md /home/contrail --uid $CONTRAIL_UID --shell /sbin/nologin --system --gid $CONTRAIL_GID $CONTRAIL_USER

COPY *.sh /
COPY pip.conf /etc/

CMD ["/usr/bin/tail","-f","/dev/null"]
