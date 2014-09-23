minihadoop
==========
This is a configuration repo to run a non-trivial Hadoop cluster on a single laptop. It serves the same purpose 
as [minicluster](http://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/CLIMiniCluster.html). However,
it is a more realistic setup because all daemons are run in dedicated JVM's. It's designed for test iterations during
feature development in Hadoop (commons, HDFS, YARN, MapReduce).

Let us denote the local path at which Hadoop repo is checked out /path/hadoopsrc. To build all packages, we invoke

```bash
/path/hadoopsrc$ mvn clean package -Pdist -DskipTests -Dmaven.javadoc.skip
```
This creates a runnable distribution location under /path/hadoopsrc/hadoop-dist/target/hadoop-<version>
