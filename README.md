Scripts to create mongodb deployments on our build machines. When you have such deployment, you can modify sources, add some useful printfs, build and run the database locally. You will see your printfs. Alternatively you can attach debuger to any of the processes and step through the stack. It helps to organize experimentation with code and troubleshooting of problems.

Script make_single.sh creates directory "single" with a deployment of a single mongodb process. No replication, no shards. The simplest and lightest possible deployment. Only one mongod process is running.

Script make_rset.sh creates directory "rset" with deployment of a mongod replica set. When you start it, you get three mongod processes running. You initialize it with script init.sh and you have a local replica set running.

Script make_cluster.sh creates directory "cluster" with deployment of a minimal sharding cluster. It includes a replica set for data, replica set for configuration and mongos router. When it is running, there are 7 processes: six mongod processes and one mongos process. This deployment requires multiple configuration steps, which are described in the script itself.

Summary: it's not perfect but it's useful.
I am open for suggestions. If you have questions or problems, I am happy to help.
