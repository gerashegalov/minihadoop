minihadoop
==========
This is a configuration repo to run a non-trivial Hadoop cluster on a single laptop. It serves the same purpose 
as [minicluster](http://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/CLIMiniCluster.html). However,
it is a more realistic setup because all daemons are run in dedicated JVM's. It's designed for test iterations during
feature development in Hadoop (commons, HDFS, YARN, MapReduce).

This configuration consists of 
- Federation of two NameNodes for /tmp (node 1) and /user (node 2) namespaces
- Two DataNodes (node 1 and node 2)
- ResourceManager (node 1)
- Two NodeManagers (node 1 and node 2)
- JobHistoryServer (node 1)

Let us denote the local path at which Hadoop repo is checked out /path1/hadoopsrc. To build all packages, we invoke

```bash
/path1/hadoopsrc$ mvn clean package -Pdist -DskipTests -Dmaven.javadoc.skip
```
This creates a runnable distribution location under ```/path1/hadoopsrc/hadoop-dist/target/hadoop-<version>```

This location has to be exported to the script ```bin/pseudo1.sh``` via the following environment variable:
```
export G_HADOOP_HOME=/path1/hadoopsrc/hadoop-dist/target/hadoop-<version>
export PATH=${PATH}:${G_HADOOP_HOME}/bin"
```

Let us clone this repo minihadoop under /path2 and export the common configuration directory :
```bash
/path2$ git clone https://github.com/gerashegalov/minihadoop
/path2$ export HADOOP_CONF_DIR=${PWD}/minihadoop/conf
/path2$ export PATH=${PATH}:${PWD}/minihadoop/bin
```

When invoking for the first time, we need to format the name spaces for federation:
```bash
/path2$ pseudo1.sh format
```

This will create a bunch of directies under ```$HADOOP_CONF_DIR``` for node1 and node2. The clash between major versions is avoided by using the version suffix. This is useful when working on multiple branches simultaneously.

To start the cluster:
```bash
/path2$ pseudo1.sh start
```

To stop the cluster:
```bash
/path2$ pseudo1.sh stop
```

If you want to keep data when upgrades are needed after rebasing and recompiling:
```bash
# Hit Ctrl-C when you see NN booted and use start
/path2$ pseudo1.sh upgrade
```

