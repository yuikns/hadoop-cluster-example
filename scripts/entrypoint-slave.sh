#!/usr/bin/env bash

source /etc/profile
source /etc/bashrc

[ ! -d /var/log/spark/ ] && mkdir -p /var/log/spark/

sudo service zookeeper-server start
sudo service hadoop-yarn-nodemanager start
sudo service hadoop-hdfs-datanode start
sudo service spark-worker start

sudo service hbase-regionserver start

echo "slave is ready, rock it!"
# Holding over here
/usr/sbin/sshd -D

