#!/bin/bash

if [ "${1}" == "--debug" ]; then
  shift
  set -x
fi

if [ "${1}" == "--old-bash" ]; then
  OLD_BASH=1
  shift
fi

if [ "${1}" == "--print" ]; then
  PRINT=1
  shift
fi

cd ${HADOOP_CONF_DIR}

G_HADOOP_VERSION=$(hadoop version | grep Hadoop | grep -o '\d\+\(\.\d\+\)\+')


#
# node specific opts
#

HDFS_KEYS[1]="-Dhadoop.tmp.dir=${PWD}/tmp1
  -Ddfs.nameservice.id=ns1
  -Dmy.hdfs.home.dir=${PWD}/hdfs1-${G_HADOOP_VERSION}
  -Ddfs.datanode.address=localhost:50010
  -Ddfs.datanode.http.address=localhost:50075
  -Ddfs.datanode.ipc.address=localhost:50020"

HDFS_KEYS[2]="-Dhadoop.tmp.dir=${PWD}/tmp2
  -Ddfs.nameservice.id=ns2
  -Dmy.hdfs.home.dir=${PWD}/hdfs2-${G_HADOOP_VERSION}
  -Ddfs.datanode.address=localhost:50011
  -Ddfs.datanode.http.address=localhost:50076
  -Ddfs.datanode.ipc.address=localhost:50021"

YARN_KEYS[1]="-Dhadoop.tmp.dir=${PWD}/tmp1
  -Dyarn.nodemanager.log-dirs=${PWD}/userlogs1
  -Dyarn.nodemanager.localizer.address=localhost:8040
  -Dyarn.nodemanager.address=localhost:8041
  -Dyarn.nodemanager.webapp.address=localhost:8042
  -Dyarn.nodemanager.health-checker.script.opts=/tmp/decommission1
  -Dmapreduce.shuffle.port=13562"

YARN_KEYS[2]="-Dhadoop.tmp.dir=${PWD}/tmp2
  -Dyarn.nodemanager.log-dirs=${PWD}/userlogs2
  -Dyarn.nodemanager.localizer.address=localhost:8043
  -Dyarn.nodemanager.address=localhost:8044
  -Dyarn.nodemanager.webapp.address=localhost:8045
  -Dyarn.nodemanager.health-checker.script.opts=/tmp/decommission2
  -Dmapreduce.shuffle.port=13563"

nodeEnv() {
  unset NODE_ENV

  NODE_ENV="HADOOP_LOG_DIR=${PWD}/logs ${NODE_ENV}"
  NODE_ENV="HADOOP_IDENT_STRING=${USER}-node${1} ${NODE_ENV}"
  if [[ "${OLD_BASH}" == "1" ]]; then
    NODE_ENV="HADOOP_HDFS_IDENT_STRING=${HADOOP_IDENT_STRING} ${NODE_ENV}"
    NODE_ENV="YARN_IDENT_STRING=${HADOOP_IDENT_STRING} ${NODE_ENV}"
    NODE_ENV="HADOOP_MAPREDUCE_IDENT_STRING=${HADOOP_IDENT_STRING} ${NODE_ENV}"
    NODE_ENV="YARN_LOG_DIR=${HADOOP_LOG_DIR} ${NODE_ENV}"
    NODE_ENV="HADOOP_MAPRED_LOG_DIR=${HADOOP_LOG_DIR} ${NODE_ENV}"
  fi
}

runHdfsDaemon() {
  if [ "${OLD_BASH}" == "1" ]; then
    cmd="${NODE_ENV} ${G_HADOOP_HOME}/sbin/hadoop-daemon.sh --config ${PWD} ${CMD} ${2} ${HDFS_KEYS[${1}]}"
  else
    cmd="${NODE_ENV} ${G_HADOOP_HOME}/bin/hdfs --config ${PWD} --daemon ${CMD} ${2} ${HDFS_KEYS[${1}]}"
  fi

  if [ "${PRINT}" == "1" ]; then
    echo $cmd
  else
    eval $cmd
  fi
}

runYarnDaemon() {
  if [ "${OLD_BASH}" == "1" ]; then
    cmd="${NODE_ENV} ${G_HADOOP_HOME}/sbin/yarn-daemon.sh --config ${PWD} ${CMD} ${2} ${YARN_KEYS[${1}]}"
  else
    cmd="${NODE_ENV} ${G_HADOOP_HOME}/bin/yarn --config ${PWD} --daemon ${CMD} ${2} ${YARN_KEYS[${1}]}"
  fi

  if [ "${PRINT}" == "1" ]; then
    echo $cmd
  else
    eval $cmd
  fi
}

runMapredDaemon() {
  if [ "${OLD_BASH}" == "1" ]; then
    cmd="${NODE_ENV} ${G_HADOOP_HOME}/sbin//mr-jobhistory-daemon.sh --config ${PWD} ${CMD} ${1}"
  else
    cmd="${NODE_ENV} ${G_HADOOP_HOME}/bin/mapred --config ${PWD} --daemon ${CMD} ${1}"
  fi

  if [ "${PRINT}" == "1" ]; then
    echo $cmd
  else
    eval $cmd
  fi
}

runDaemons() {
  node="${1}"
  shift

  while (( "$#" )); do
    case "${1}" in
      namenode)
        runHdfsDaemon ${node} ${1}
        ;;
      datanode)
        runHdfsDaemon ${node} ${1}
        ;;
      resourcemanager)
        runYarnDaemon ${node} ${1}
        ;;
      nodemanager)
        runYarnDaemon ${node} ${1}
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
  runDaemons 1 namenode datanode resourcemanager nodemanager historyserver
fi

if [ "${NODE2}" == "yes" ]; then
  nodeEnv "2" 
  runDaemons 2 namenode datanode nodemanager
fi

