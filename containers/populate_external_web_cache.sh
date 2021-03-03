#!/bin/bash -e


CACHE_DIR=${CACHE_DIR:-'/tmp/cache'}

mkdir $CACHE_DIR
cd $CACHE_DIR

wget -nv -t3 -P containernetworking/cni/releases/download/v0.3.0 https://github.com/containernetworking/cni/releases/download/v0.3.0/cni-v0.3.0.tgz
wget -nv -t3 -P tungstenfabric/tf-third-party-cache/raw/master/tshark https://github.com/tungstenfabric/tf-third-party-cache/raw/master/tshark/tshark3_2.tar.bz2
wget -nv -t3 -P dnsmasq  http://www.thekelleys.org.uk/dnsmasq/dnsmasq-2.80.tar.xz

wget -nv -t3 -P rabbitmq/erlang/packages/el/7 https://packagecloud.io/rabbitmq/erlang/packages/el/7/erlang-21.3.8.21-1.el7.x86_64.rpm
wget -nv -t3 -P rabbitmq/rabbitmq-server/packages/el/7 https://packagecloud.io/rabbitmq/rabbitmq-server/packages/el/7/rabbitmq-server-3.7.20-1.el7.noarch.rpm

wget -nv -t3 -P 2.7 https://bootstrap.pypa.io/2.7/get-pip.py
wget -nv -t3 -P dist/cassandra/3.11.3 https://archive.apache.org/dist/cassandra/3.11.3/apache-cassandra-3.11.3-bin.tar.gz
wget -nv -t3 -P dist/zookeeper/zookeeper-3.6.1 https://archive.apache.org/dist/zookeeper/zookeeper-3.6.1/apache-zookeeper-3.6.1-bin.tar.gz
wget -nv -t3 -P tungstenfabric/tf-third-party-cache/blob/master/kafka https://github.com/tungstenfabric/tf-third-party-cache/blob/master/kafka/kafka_2.11-2.3.1.tgz

