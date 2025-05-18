#!/bin/bash

function create_config_file() {
    DIR=`pwd`/$1
    PORT=$2
    CONF=$DIR/mongod.conf

    cat > $CONF  << 'EOF'
storage:
  dbPath:  DIR/data
systemLog:
  destination: file
  logAppend: true
  path:  DIR/var/mongod.log
net:
  port: PORT
  bindIp: 127.0.0.1
security:
  authorization: disabled
replication:
  replSetName: rs0
sharding:
  clusterRole: shardsvr
EOF

    sed -i "s|DIR|$DIR|g" $CONF
    sed -i "s|PORT|$PORT|g" $CONF
}

function create_config_file_cfg() {
    DIR=`pwd`/$1
    PORT=$2
    CONF=$DIR/mongod.conf

    cat > $CONF  << 'EOF'
storage:
  dbPath:  DIR/data
systemLog:
  destination: file
  logAppend: true
  path:  DIR/var/mongod.log
net:
  port: PORT
  bindIp: 127.0.0.1
security:
  authorization: disabled
replication:
  replSetName: configRS
sharding:
  clusterRole: configsvr
EOF

    sed -i "s|DIR|$DIR|g" $CONF
    sed -i "s|PORT|$PORT|g" $CONF
}

function create_config_file_router() {
    DIR=`pwd`/$1
    PORT=$2
    CONF=$DIR/mongos.conf

    cat > $CONF  << 'EOF'
systemLog:
  destination: file
  logAppend: true
  path:  DIR/var/mongos.log
net:
  port: PORT
  bindIp: 127.0.0.1
sharding:
  configDB: configRS/localhost:PORT3,localhost:PORT4,localhost:PORT5
EOF

    sed -i "s|DIR|$DIR|g" $CONF

    sed -i "s|PORT3|$PORT3|g" $CONF
    sed -i "s|PORT4|$PORT4|g" $CONF
    sed -i "s|PORT5|$PORT5|g" $CONF
    sed -i "s|PORT|$PORT|g" $CONF
}

# Allow overriding the port number
PORT0=27017
if [ "$1" != "" ]; then
	PORT0=$1
fi

PORT1=$((PORT0 + 1))
PORT2=$((PORT1 + 1))

PORT3=$((PORT2 + 1))
PORT4=$((PORT3 + 1))
PORT5=$((PORT4 + 1))
PORT6=$((PORT5 + 1))

if [ -d "cluster" ]; then
	echo "Directory cluster already exists. Quitting..."
	exit 1
fi

mkdir cluster
cd cluster

echo "Create local links to mongod, mongos and mongo executables."
ln -s ~/mongo/bazel-bin/install/bin/mongod mongod
ln -s ~/mongo/bazel-bin/install/bin/mongos mongos
ln -s ~/mongo/bazel-bin/install/bin/mongo mongo

echo "Create directories for data and logs."
mkdir -p rs0-0/data rs0-1/data rs0-2/data
mkdir -p rs0-0/var rs0-1/var rs0-2/var

mkdir -p cfg-0/data cfg-1/data cfg-2/data
mkdir -p cfg-0/var cfg-1/var cfg-2/var

mkdir -p router/data router/var

echo "Create configuration files for mongod."
create_config_file "rs0-0"  $PORT0
create_config_file "rs0-1"  $PORT1
create_config_file "rs0-2"  $PORT2

create_config_file_cfg "cfg-0"  $PORT3
create_config_file_cfg "cfg-1"  $PORT4
create_config_file_cfg "cfg-2"  $PORT5

create_config_file_router "router" $PORT6

echo "Create start script for mongod processes."
cat > rset_start.sh  << 'EOF'
#!/bin/bash
DIR/mongod --config DIR/rs0-0/mongod.conf --fork
DIR/mongod --config DIR/rs0-1/mongod.conf --fork
DIR/mongod --config DIR/rs0-2/mongod.conf --fork

DIR/mongod --config DIR/cfg-0/mongod.conf --fork
DIR/mongod --config DIR/cfg-1/mongod.conf --fork
DIR/mongod --config DIR/cfg-2/mongod.conf --fork

ps -ef|grep mongod | grep -v grep
EOF

echo "Create start script for mongos."
cat > router_start.sh  << 'EOF'
#!/bin/bash
DIR/mongos --config DIR/router/mongos.conf --fork
ps -ef|grep mongos | grep -v grep
EOF

echo "Create stop script."
cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f DIR/mongos

DIR/mongo --port PORT0  --eval "db.adminCommand({shutdown: 1})" &
DIR/mongo --port PORT1  --eval "db.adminCommand({shutdown: 1})" &
DIR/mongo --port PORT2  --eval "db.adminCommand({shutdown: 1})" &

DIR/mongo --port PORT3  --eval "db.adminCommand({shutdown: 1})" &
DIR/mongo --port PORT4  --eval "db.adminCommand({shutdown: 1})" &
DIR/mongo --port PORT5  --eval "db.adminCommand({shutdown: 1})" &

wait
ps -ef|grep mongod | grep -v grep
ps -ef|grep mongos | grep -v grep
EOF

echo "Create client script."
cat > config_client.sh << 'EOF'
#!/bin/bash
echo "Connect to mongos"
DIR/mongo --port PORT6
EOF

echo "Create data replica set initialization text."
cat > rset_init.txt << 'EOF'
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "localhost:PORT0" },
    { _id: 1, host: "localhost:PORT1" },
    { _id: 2, host: "localhost:PORT2" }
  ]
})
EOF

echo "Create data replica set initialization script."
cat > rset_init.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT0 < DIR/rset_init.txt
EOF

echo "Create config replica set initialization text."
cat > config_init.txt << 'EOF'
rs.initiate({
  _id: "configRS",
  configsvr: true,
  members: [
    { _id: 0, host: "localhost:PORT3" },
    { _id: 1, host: "localhost:PORT4" },
    { _id: 2, host: "localhost:PORT5" }
  ]
})
EOF

echo "Create config replica set initialization script."
cat > config_init.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT3 < DIR/config_init.txt
EOF

echo "Create router initialization text."
cat > router_init.txt << 'EOF'
sh.addShard("rs0/localhost:PORT0,localhost:PORT1,localhost:PORT2")
sh.enableSharding("testdb")
sh.shardCollection("testdb.mycollection", { "_id": "hashed" })
sh.status()
EOF

echo "Create router initialization script."
cat > router_init.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT6 < DIR/router_init.txt
EOF

echo "Create router client script."
cat > router_client.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT6
EOF


PWD=`pwd`
echo "Set working directory $PWD"
sed -i "s|DIR|$PWD|g" *.sh *.txt

echo "Set port number"
sed -i "s/PORT0/$PORT0/g" *.sh *.txt
sed -i "s/PORT1/$PORT1/g" *.sh *.txt
sed -i "s/PORT2/$PORT2/g" *.sh *.txt
sed -i "s/PORT3/$PORT3/g" *.sh *.txt
sed -i "s/PORT4/$PORT4/g" *.sh *.txt
sed -i "s/PORT5/$PORT5/g" *.sh *.txt
sed -i "s/PORT6/$PORT6/g" *.sh *.txt

chmod +x *.sh

echo 
echo Perform following steps:
echo 	1. Start replica sets with script rset_start.sh
echo 	2. Initialize data replica set with script rset_init.sh
echo 	3. Initialize configuration replica set with script config_init.sh
echo 	4. Start mongos with script router_start.sh
echo 	5. Initialize mongos with script router_init.sh
echo 	6. Connect to the router with script router_client.sh
echo 

