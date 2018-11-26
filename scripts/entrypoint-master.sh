#!/usr/bin/env bash

source /etc/profile
source /etc/bashrc

# Spark Log
[ ! -d /var/log/spark/ ] && mkdir -p /var/log/spark/

# Initialize MySQL for hive
# MySQL service is provided by TiDB
MYSQL_HOST="tidb"
MYSQL_ROOT_USER="root"
METASTORE_DB="metastore"
METASTORE_HIVE_DIR="$HIVE_HOME/scripts/metastore/upgrade/mysql/"
METASTORE_HIVE_SCHEMA="$METASTORE_HIVE_DIR/hive-schema-1.2.0.mysql.sql"


function wait_for_mysql() {
  mysqladmin ping -u $MYSQL_ROOT_USER -h $MYSQL_HOST  2>/dev/null 1>/dev/null
  local is_running=${?}
  if [ $is_running -eq 1 ]; then
    echo "MySQL is not ready yet, try again"
    # return 0, continue waiting
    return 0
  else
    echo "MySQL is UP"
    return 1
  fi
}

while wait_for_mysql ;
do
  sleep 3
done


CHECK_DB=$( mysql -u $MYSQL_ROOT_USER -ss  -h $MYSQL_HOST -e "SELECT count(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$METASTORE_DB'" )

if [ $CHECK_DB == 1 ]; then
  echo "DB for hive $METASTORE_DB is exists. skip"
else
  echo "DB for hive $METASTORE_DB is not exists. create it.."
  mysql -u $MYSQL_ROOT_USER -s -N  -h $MYSQL_HOST -e "CREATE DATABASE $METASTORE_DB;"
  echo "Import Schema...$METASTORE_HIVE_SCHEMA"
  if [ -f $METASTORE_HIVE_SCHEMA ]; then
    echo "Schema SQL file exists, importing..."
    pushd $METASTORE_HIVE_DIR
      mysql -u $MYSQL_ROOT_USER  -h $MYSQL_HOST -D $METASTORE_DB < $METASTORE_HIVE_SCHEMA
    popd # $METASTORE_HIVE_DIR
  else
    echo '###WARNING#### Schema SQL file NOT exists....!!!!!!'
  fi
fi

unset CHECK_DB
unset METASTORE_HIVE_DIR
unset METASTORE_HIVE_SCHEMA

# CHECK 

MYSQL_HIVE_USER="hiveuser"
MYSQL_HIVE_PASSWORD="hivepassword"

CHECK_HIVE_USER=$( mysql -u $MYSQL_HIVE_USER -ss  -h $MYSQL_HOST -p$MYSQL_HIVE_PASSWORD -D $METASTORE_DB -e "SELECT count(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$METASTORE_DB'" )

if [ -z $CHECK_HIVE_USER ]; then
  echo "user $MYSQL_HIVE_USER not exists. create it.."
  mysql -u $MYSQL_ROOT_USER -h $MYSQL_HOST -e "CREATE USER '$MYSQL_HIVE_USER'@'%' IDENTIFIED BY '$MYSQL_HIVE_PASSWORD'"
  mysql -u $MYSQL_ROOT_USER -h $MYSQL_HOST -e "GRANT all on *.* to '$MYSQL_HIVE_USER'@'%' identified by '$MYSQL_HIVE_PASSWORD'"
  mysql -u $MYSQL_ROOT_USER -h $MYSQL_HOST -e "flush privileges"
fi

# End of MySQL


sudo service zookeeper-server start
sudo service hadoop-yarn-proxyserver start
sudo service hadoop-yarn-resourcemanager start
sudo service hadoop-yarn-nodemanager start
sudo service hadoop-hdfs-namenode start
sudo service hadoop-hdfs-datanode start

sudo -u hdfs hdfs dfs -mkdir -p /app
sudo -u hdfs hdfs dfs -chmod 777 /app
sudo -u hdfs hdfs dfs -mkdir -p /user
sudo -u hdfs hdfs dfs -chmod 755 /user

# for hive
sudo -u hdfs hdfs dfs -mkdir -p /user/hive/warehouse
sudo -u hdfs hdfs dfs -chown -R root /user/hive
# for hive and hadoop-mapreduce-historyserver and so on
sudo -u hdfs hdfs dfs -mkdir -p /tmp
sudo -u hdfs hdfs dfs -chmod 777 /tmp

# for user
sudo -u hdfs hdfs dfs -mkdir -p /user/root
sudo -u hdfs hdfs dfs -chown -R root /user/root

sudo service hadoop-mapreduce-historyserver start

sudo service spark-worker start
sudo service spark-master start

sudo service hbase-regionserver start
sudo service hbase-master start
sudo service hbase-thrift start

echo "master is ready, rock it!"
# Holding over here
/usr/sbin/sshd -D

