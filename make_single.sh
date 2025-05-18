#!/bin/bash

# Allow overriding the port number
PORT=27017
if [ "$1" != "" ]; then
	PORT=$1
fi

if [ -d "single" ]; then
	echo "Directory single already exists. Quitting..."
	exit 1
fi

mkdir single
cd single

echo "Create local links to mongod and mongo executables."
ln -s ~/mongo/bazel-bin/install/bin/mongod mongod
ln -s ~/mongo/bazel-bin/install/bin/mongo mongo

echo "Create directories for data and logs."
mkdir data
mkdir var

echo "Create configuration file for mongod."
cat > mongod.conf  << 'EOF'
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
  authorization: disabled  # Set to 'enabled' for authentication
EOF

echo "Create start script."
cat > start.sh  << 'EOF'
#!/bin/bash
DIR/mongod --config DIR/mongod.conf --fork
EOF

echo "Create stop script."
cat > stop.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT  --eval "db.adminCommand({shutdown: 1})"
EOF

echo "Create client script."
cat > client.sh << 'EOF'
#!/bin/bash
DIR/mongo --port PORT
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
DIR/mongo --port PORT < DIR/session.txt
EOF

PWD=`pwd`
echo "Set working directory $PWD"
sed -i "s|DIR|$PWD|g" mongod.conf *.sh

echo "Set port number $PORT"
sed -i "s/PORT/$PORT/g" mongod.conf *.sh

chmod +x *.sh


