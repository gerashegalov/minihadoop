#!/bin/bash

if [ "${1}" == "--debug" ]; then
  shift
  set -x
fi

if [ "${1}" == "--old-bash" ]; then
  OLD_BASH=1
  shift
fi

cd ${HADOOP_CONF_DIR}

export G_HADOOP_VERSION=$(hadoop version | grep Hadoop | grep -o '\d\+\(\.\d\+\)\+')


#
# node specific opts
#

HDFS_NODE1_OPTS="-Dmy.dfs.nameservice.id=ns1
  -Dmy.hadoop.tmp.dir=${PWD}/tmp1
  -Dmy.hdfs.home.dir=${PWD}/hdfs1-${G_HADOOP_VERSION}
  -Dmy.dfs.datanode.address=localhost:50010
  -Dmy.dfs.datanode.http.address=localhost:50075
  -Dmy.dfs.datanode.ipc.address=localhost:50020"

HDFS_NODE2_OPTS="-Dmy.dfs.nameservice.id=ns2
  -Dmy.hadoop.tmp.dir=${PWD}/tmp2
  -Dmy.hdfs.home.dir=${PWD}/hdfs2-${G_HADOOP_VERSION}
  -Dmy.dfs.datanode.address=localhost:50110
  -Dmy.dfs.datanode.http.address=localhost:50175
  -Dmy.dfs.datanode.ipc.address=localhost:50120"

HDFS_OPTS[1]=${HDFS_NODE1_OPTS}
HDFS_OPTS[2]=${HDFS_NODE2_OPTS}


YARN_NODE1_OPTS="
  -Dmy.hadoop.tmp.dir=${PWD}/tmp1
  -Dmy.yarn.nodemanager.log-dirs=${PWD}/userlogs1
  -Dmy.yarn.nodemanager.localizer.address=localhost:8040
  -Dmy.yarn.nodemanager.address=localhost:8041
  -Dmy.yarn.nodemanager.webapp.address=localhost:8042
  -Dmy.mapreduce.shuffle.port=13562
  -Dmy.decommission.file=/tmp/decommission1"

YARN_NODE2_OPTS="
  -Dmy.hadoop.tmp.dir=${PWD}/tmp2
  -Dmy.yarn.nodemanager.log-dirs=${PWD}/userlogs2
  -Dmy.yarn.nodemanager.localizer.address=localhost:8140
  -Dmy.yarn.nodemanager.address=localhost:8141
  -Dmy.yarn.nodemanager.webapp.address=localhost:8142
  -Dmy.mapreduce.shuffle.port=13563
  -Dmy.decommission.file=/tmp/decommission2"

YARN_OPTS[1]=${YARN_NODE1_OPTS}
YARN_OPTS[2]=${YARN_NODE2_OPTS}

nodeEnv() {
  export HADOOP_LOG_DIR=${PWD}/logs

  export HADOOP_IDENT_STRING=${USER}-node${1}
  if [[ "${OLD_BASH}" == "1" ]]; then
    export HADOOP_HDFS_IDENT_STRING="${HADOOP_IDENT_STRING}"
    export YARN_IDENT_STRING=${HADOOP_IDENT_STRING}
    export HADOOP_MAPREDUCE_IDENT_STRING="${HADOOP_IDENT_STRING}"
    export YARN_LOG_DIR="${HADOOP_LOG_DIR}"
    export HADOOP_MAPRED_LOG_DIR="${HADOOP_LOG_DIR}"
  fi
  export HADOOP_NAMENODE_OPTS="${HDFS_OPTS[${1}]}"
  export HADOOP_DATANODE_OPTS="${HDFS_OPTS[${1}]}"
  export YARN_RESOURCEMANAGER_OPTS="${YARN_OPTS[${1}]}"
  export YARN_NODEMANAGER_OPTS="${YARN_OPTS[${1}]}"
}

runHdfsDaemon() {
  if [ "${OLD_BASH}" == "1" ]; then
    ${G_HADOOP_HOME}/sbin/hadoop-daemon.sh --config ${PWD} ${CMD} ${1}
  else
    ${G_HADOOP_HOME}/bin/hdfs --config ${PWD} --daemon ${CMD} ${1}
  fi
}

runYarnDaemon() {
  if [ "${OLD_BASH}" == "1" ]; then
    ${G_HADOOP_HOME}/sbin/yarn-daemon.sh --config ${PWD} ${CMD} ${1}
  else
    ${G_HADOOP_HOME}/bin/yarn --config ${PWD} --daemon ${CMD} ${1}
  fi
}

runMapredDaemon() {
  if [ "${OLD_BASH}" == "1" ]; then
    ${G_HADOOP_HOME}/sbin//mr-jobhistory-daemon.sh --config ${PWD} ${CMD} ${1}
  else
    ${G_HADOOP_HOME}/bin/mapred --config ${PWD} --daemon ${CMD} ${1}
  fi
}

runDaemons() {
  while (( "$#" )); do
    case "${1}" in
      namenode)
        runHdfsDaemon ${1}
        ;;
      datanode)
        runHdfsDaemon ${1}
        ;;
      resourcemanager)
        runYarnDaemon ${1}
        ;;
      nodemanager)
        runYarnDaemon ${1}
        ;;
      historyserver)
        runMapredDaemon ${1}
        ;;
      *)
    esac

    shift
  done
}

if [ "${1}" == "format" ]; then
  clid="MY.CID-$(date +%s)"
  nodeEnv "1"
  ${G_HADOOP_HOME}/bin/hdfs namenode -format -clusterId ${clid}

  nodeEnv "2"
  ${G_HADOOP_HOME}/bin/hdfs namenode -format -clusterId ${clid}

  exit 0
fi

if [ "${1}" == "upgrade" ] || [ "${1}" == "finalize" ] || [ "${1}" == "rollback" ]; then
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
  nodeEnv "1"
  runDaemons namenode datanode resourcemanager nodemanager historyserver
fi

if [ "${NODE2}" == "yes" ]; then
  nodeEnv "2"
  runDaemons namenode datanode nodemanager
fi

