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
EOF

    sed -i "s|DIR|$DIR|g" $CONF
    sed -i "s|PORT|$PORT|g" $CONF
}

# Allow overriding the port number
PORT0=27017
if [ "$1" != "" ]; then
	PORT0=$1
fi

PORT1=$((PORT0 + 1))
PORT2=$((PORT1 + 1))

if [ -d "rset" ]; then
	echo "Directory rset already exists. Quitting..."
	exit 1
fi

mkdir rset
cd rset

echo "Create local links to mongod and mongo executables."
ln -s ~/mongo/bazel-bin/install/bin/mongod mongod
ln -s ~/mongo/bazel-bin/install/bin/mongo mongo

echo "Create directories for data and logs."
mkdir -p rs0-0/data rs0-1/data rs0-2/data
mkdir -p rs0-0/var rs0-1/var rs0-2/var

echo "Create configuration files for mongod."
create_config_file "rs0-0"  $PORT0
create_config_file "rs0-1"  $PORT1
create_config_file "rs0-2"  $PORT2

echo "Create start script."
cat > start.sh  << 'EOF'
#!/bin/bash
DIR/mongod --config DIR/rs0-0/mongod.conf --fork
DIR/mongod --config DIR/rs0-1/mongod.conf --fork
DIR/mongod --config DIR/rs0-2/mongod.conf --fork
EOF

echo "Create stop script."
cat > stop.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT0  --eval "db.adminCommand({shutdown: 1})"
DIR/mongo --port PORT1  --eval "db.adminCommand({shutdown: 1})"
DIR/mongo --port PORT2  --eval "db.adminCommand({shutdown: 1})"
EOF

echo "Create client script."
cat > client.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT0
EOF

echo "Create initialization script."
cat > init.txt << 'EOF'
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "localhost:PORT0" },
    { _id: 1, host: "localhost:PORT1" },
    { _id: 2, host: "localhost:PORT2" }
  ]
})
EOF

echo "Create initialization"
cat > init.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT0 < DIR/init.txt
EOF

echo "Create demo script."
cat > session.txt << 'EOF'
show dbs
use myDatabase
db.createCollection("myCollection")
db.myCollection.insertOne({ name: "test" })
db.myCollection.find()
exit
EOF

echo "Create demo."
cat > demo.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT0 < DIR/session.txt
EOF

PWD=`pwd`
echo "Set working directory $PWD"
sed -i "s|DIR|$PWD|g" *.sh *.txt

echo "Set port number"
sed -i "s/PORT0/$PORT0/g" *.sh *.txt
sed -i "s/PORT1/$PORT1/g" *.sh *.txt
sed -i "s/PORT2/$PORT2/g" *.sh *.txt

chmod +x *.sh

echo "You need to run start.sh to start the replica set and then run init.sh to initialize it"
echo "Attention: please run client with command rs.status(), find the primary node, and adjust client.sh and demo.sh to connect to the primary node"
