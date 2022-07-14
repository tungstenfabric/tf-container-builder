#!/bin/bash -e

# here we have ALL versions cause master branch is used to initialise cache for all branches

if ! which wget; then
   echo "ERROR: wget is not found. please install it. exit"
   exit 1
fi

CACHE_DIR=${CACHE_DIR:-'/tmp/cache'}

mkdir -p $CACHE_DIR || true
cd $CACHE_DIR

wget -nv -t3 -P containernetworking/cni/releases/download/v0.3.0 https://github.com/containernetworking/cni/releases/download/v0.3.0/cni-v0.3.0.tgz
wget -nv -t3 -P tungstenfabric/tf-third-party-cache/raw/master/tshark https://github.com/tungstenfabric/tf-third-party-cache/raw/master/tshark/tshark3_2.tar.bz2
wget -nv -t3 -P dnsmasq  http://www.thekelleys.org.uk/dnsmasq/dnsmasq-2.80.tar.xz

wget -nv -t3 -P rabbitmq/erlang/packages/el/7/erlang-21.3.8.21-1.el7.x86_64.rpm https://packagecloud.io/rabbitmq/erlang/packages/el/7/erlang-21.3.8.21-1.el7.x86_64.rpm/download.rpm
wget -nv -t3 -P rabbitmq/rabbitmq-server/packages/el/7/rabbitmq-server-3.7.20-1.el7.noarch.rpm https://packagecloud.io/rabbitmq/rabbitmq-server/packages/el/7/rabbitmq-server-3.7.20-1.el7.noarch.rpm/download.rpm
# from 21.4
wget -nv -t3 -P rabbitmq/erlang/packages/el/8/erlang-21.3.8.21-1.el8.x86_64.rpm https://packagecloud.io/rabbitmq/erlang/packages/el/8/erlang-21.3.8.21-1.el8.x86_64.rpm/download.rpm
wget -nv -t3 -P rabbitmq/rabbitmq-server/packages/el/7/rabbitmq-server-3.7.28-1.el7.noarch.rpm https://packagecloud.io/rabbitmq/rabbitmq-server/packages/el/7/rabbitmq-server-3.7.28-1.el7.noarch.rpm/download.rpm
wget -nv -t3 -P rabbitmq/rabbitmq-server/packages/el/8/rabbitmq-server-3.7.28-1.el8.noarch.rpm https://packagecloud.io/rabbitmq/rabbitmq-server/packages/el/8/rabbitmq-server-3.7.28-1.el8.noarch.rpm/download.rpm

wget -nv -t3 -P pip/2.7 https://bootstrap.pypa.io/pip/2.7/get-pip.py

wget -nv -t3 -P dist/cassandra/3.11.3 https://archive.apache.org/dist/cassandra/3.11.3/apache-cassandra-3.11.3-bin.tar.gz

# up to 2011.L1
wget -nv -t3 -P dist/zookeeper/zookeeper-3.6.1 https://archive.apache.org/dist/zookeeper/zookeeper-3.6.1/apache-zookeeper-3.6.1-bin.tar.gz
# from 2011.L2, 21.3
wget -nv -t3 -P dist/zookeeper/zookeeper-3.6.3 https://archive.apache.org/dist/zookeeper/zookeeper-3.6.3/apache-zookeeper-3.6.3-bin.tar.gz
wget -nv -t3 -P dist/zookeeper/zookeeper-3.7.0 https://archive.apache.org/dist/zookeeper/zookeeper-3.7.0/apache-zookeeper-3.7.0-bin.tar.gz
# from 2011.L5
wget -nv -t3 -P dist/zookeeper/zookeeper-3.7.1 https://archive.apache.org/dist/zookeeper/zookeeper-3.7.1/apache-zookeeper-3.7.1-bin.tar.gz

# up to 2011.L1
wget -nv -t3 -P tungstenfabric/tf-third-party-cache/blob/master/kafka https://github.com/tungstenfabric/tf-third-party-cache/blob/master/kafka/kafka_2.11-2.3.1.tgz?raw=true
# from 2011.L2, 21.3
# kafka 2.6.2 was moved to archive
#wget -nv -t3 -P apache/kafka/2.6.2 https://mirror.linux-ia64.org/apache/kafka/2.6.2/kafka_2.12-2.6.2.tgz
wget -nv -t3 -P dist/kafka/2.6.2 https://archive.apache.org/dist/kafka/2.6.2/kafka_2.12-2.6.2.tgz
wget -nv -t3 -P dist/kafka/2.6.3 https://archive.apache.org/dist/kafka/2.6.3/kafka_2.12-2.6.3.tgz

wget -nv -t3 -P tungstenfabric/tf-third-party-cache/blob/master/redis https://github.com/tungstenfabric/tf-third-party-cache/blob/master/redis/redis40u-4.0.14-2.el7.ius.x86_64.rpm?raw=true
# from 2011.L3, 21.3
wget -nv -t3 -P tungstenfabric/tf-third-party-cache/blob/master/redis https://github.com/tungstenfabric/tf-third-party-cache/blob/master/redis/redis-6.0.15-1.el7.remi.x86_64.rpm?raw=true

wget -nv -t3 -P Juniper/ansible-junos-stdlib/archive https://github.com/Juniper/ansible-junos-stdlib/archive/2.4.2.tar.gz

wget -nv -t3 -P 30590/eng https://downloadmirror.intel.com/30590/eng/800%20series%20comms%20binary%20package%201.3.30.0.zip

wget -nv -t3 -P linux/centos/7/x86_64/stable/Packages https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.4.12-3.1.el7.x86_64.rpm

wget -nv -t3 -P pub/archive/epel/8.4/Everything/x86_64/Packages/s https://archives.fedoraproject.org/pub/archive/epel/8.4/Everything/x86_64/Packages/s/sshpass-1.06-9.el8.x86_64.rpm

wget -nv -t3 -P maven2/io/netty/netty-all/4.1.39.Final https://repo1.maven.org/maven2/io/netty/netty-all/4.1.39.Final/netty-all-4.1.39.Final.jar
wget -nv -t3 -P maven2/ch/qos/logback/logback-classic/1.2.9 https://repo1.maven.org/maven2/ch/qos/logback/logback-classic/1.2.9/logback-classic-1.2.9.jar
wget -nv -t3 -P maven2/ch/qos/logback/logback-core/1.2.9 https://repo1.maven.org/maven2/ch/qos/logback/logback-core/1.2.9/logback-core-1.2.9.jar

wget -nv -t3 -P centos/7/os/x86_64/Packages http://mirror.centos.org/centos/7/os/x86_64/Packages/ntpdate-4.2.6p5-29.el7.centos.2.x86_64.rpm
wget -nv -t3 -P centos/7/os/x86_64/Packages http://mirror.centos.org/centos/7/os/x86_64/Packages/ntp-4.2.6p5-29.el7.centos.2.x86_64.rpm

wget -nv -t3 -P tungstenfabric/tf-third-party-cache/blob/master/libthrift https://github.com/tungstenfabric/tf-third-party-cache/blob/master/libthrift/libthrift-0.13.0.jar?raw=true
