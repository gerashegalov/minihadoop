#!/bin/bash

if [ "${1}" == "-debug" ]; then
  shift
  set -x
fi

cd ${HADOOP_CONF_DIR}
export HADOOP_LOG_DIR=${PWD}/logs
export YARN_LOG_DIR=${PWD}/logs
export HADOOP_MAPRED_LOG_DIR=${PWD}/logs

export G_HADOOP_VERSION=$(hadoop version | grep Hadoop | grep -o '\d\+\(\.\d\+\)\+')

#
# node specific opts
#

HDFS_NODE1_OPTS="-Dmy.dfs.nameservice.id=ns1
  -Dmy.hadoop.tmp.dir=${PWD}/tmp1
  -Dmy.hdfs.home.dir=${PWD}/hdfs1-${G_HADOOP_VERSION}
  -Dmy.dfs.datanode.address=0.0.0.0:50010
  -Dmy.dfs.datanode.http.address=0.0.0.0:50075
  -Dmy.dfs.datanode.ipc.address=0.0.0.0:50020"

HDFS_NODE2_OPTS="-Dmy.dfs.nameservice.id=ns2
  -Dmy.hadoop.tmp.dir=${PWD}/tmp2
  -Dmy.hdfs.home.dir=${PWD}/hdfs2-${G_HADOOP_VERSION}
  -Dmy.dfs.datanode.address=0.0.0.0:50110
  -Dmy.dfs.datanode.http.address=0.0.0.0:50175
  -Dmy.dfs.datanode.ipc.address=0.0.0.0:50120"

HDFS_OPTS[1]=${HDFS_NODE1_OPTS}
HDFS_OPTS[2]=${HDFS_NODE2_OPTS}


YARN_NODE1_OPTS="
  -Dmy.hadoop.tmp.dir=${PWD}/tmp1
  -Dmy.yarn.nodemanager.log-dirs=${PWD}/userlogs1
  -Dmy.yarn.nodemanager.localizer.address=0.0.0.0:8040
  -Dmy.yarn.nodemanager.address=0.0.0.0:8041
  -Dmy.yarn.nodemanager.webapp.address=0.0.0.0:8042
  -Dmy.mapreduce.shuffle.port=13562
  -Dmy.decommission.file=/tmp/decommission1"

YARN_NODE2_OPTS="
  -Dmy.hadoop.tmp.dir=${PWD}/tmp2
  -Dmy.yarn.nodemanager.log-dirs=${PWD}/userlogs2
  -Dmy.yarn.nodemanager.localizer.address=0.0.0.0:8140
  -Dmy.yarn.nodemanager.address=0.0.0.0:8141
  -Dmy.yarn.nodemanager.webapp.address=0.0.0.0:8142
  -Dmy.mapreduce.shuffle.port=13563
  -Dmy.decommission.file=/tmp/decommission2"

YARN_OPTS[1]=${YARN_NODE1_OPTS}
YARN_OPTS[2]=${YARN_NODE2_OPTS}

nodeEnv() {
  export HADOOP_IDENT_STRING=${USER}-node${1}
  export HADOOP_HDFS_IDENT_STRING="${HADOOP_IDENT_STRING}"
  export HADOOP_NAMENODE_OPTS="${HDFS_OPTS[${1}]} ${HADOOP_NAMENODE_OPTS}"
  export HADOOP_DATANODE_OPTS="${HDFS_OPTS[${1}]} ${HADOOP_DATANODE_OPTS}"
  export YARN_IDENT_STRING=${HADOOP_IDENT_STRING}
  export YARN_RESOURCEMANAGER_OPTS="-Dmy.hadoop.tmp.dir=${PWD}/tmp${1} ${YARN_RESOURCEMANAGER_OPTS}"
  export YARN_NODEMANAGER_OPTS="${YARN_OPTS[${1}]} ${YARN_NODEMANAGER_OPTS}"
  export HADOOP_MAPREDUCE_IDENT_STRING="${HADOOP_IDENT_STRING}"
}

if [ "${1}" == "format" ]; then
  clid="MY.CID-$(date +%s)"
  nodeEnv "1"
  ${G_HADOOP_HOME}/bin/hdfs namenode -format -clusterId ${clid}

  nodeEnv "2"
  ${G_HADOOP_HOME}/bin/hdfs namenode -format -clusterId ${clid}

  exit 0
fi

if [ "${1}" == "upgrade" ] || [ "${1}" == "finalize" ]; then
  clid="MY.CID-$(date +%s)"

  nodeEnv "1"
  ${G_HADOOP_HOME}/bin/hdfs namenode -${1}

  nodeEnv "2"
  ${G_HADOOP_HOME}/bin/hdfs namenode -${1}

  exit 0
fi

CMD=${1}
shift

case "${1}" in
  "node1")
    NODE1="yes"
    ;;
  "node2")
    NODE2="yes"
    ;;
  "")
    NODE1="yes"
    NODE2="yes"
    ;;
  *)
    NODE1="no"
    NODE2="no"
    ;;
esac

if [ "${NODE1}" == "yes" ]; then
  echo "${CMD} node1 daemons"
  nodeEnv "1"
  ${G_HADOOP_HOME}/sbin/hadoop-daemon.sh --config ${PWD} ${CMD} namenode
  ${G_HADOOP_HOME}/sbin/hadoop-daemon.sh --config ${PWD} ${CMD} datanode
  ${G_HADOOP_HOME}/sbin/yarn-daemon.sh --config ${PWD} ${CMD} resourcemanager
  ${G_HADOOP_HOME}/sbin/yarn-daemon.sh --config ${PWD} ${CMD} nodemanager
  ${G_HADOOP_HOME}/sbin//mr-jobhistory-daemon.sh --config ${PWD} ${CMD} \
    historyserver
fi

if [ "${NODE2}" == "yes" ]; then
  echo "${CMD} node2 daemons"
  nodeEnv "2"
  ${G_HADOOP_HOME}/sbin/hadoop-daemon.sh --config ${PWD} ${CMD} namenode
  ${G_HADOOP_HOME}/sbin/hadoop-daemon.sh --config ${PWD} ${CMD} datanode
  ${G_HADOOP_HOME}/sbin/yarn-daemon.sh --config ${PWD} ${CMD} nodemanager
fi

