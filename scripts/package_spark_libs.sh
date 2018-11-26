#!/usr/bin/env bash

source /etc/profile.d/bigbox.sh
source /etc/bashrc

rm -rf /tmp/spark-libs-prep
mkdir -p /tmp/spark-libs-prep
pushd /tmp/spark-libs-prep
jar cv0f spark-libs.jar -C $SPARK_HOME/jars/ .
hdfs dfs -rm -r /app/spark/jars/
hdfs dfs -mkdir -p /app/spark/jars/
hdfs dfs -put spark-libs.jar /app/spark/jars/
sudo -u hdfs hdfs dfs -chmod 777 /app/spark/jars/spark-libs.jar
popd
