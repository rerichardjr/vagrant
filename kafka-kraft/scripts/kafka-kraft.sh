#!/bin/bash

set -euxo pipefail

KAFKA_INSTALLER=kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
KAFKA_SERVER_PROPERTIES=/opt/kafka/config/kraft/server.properties
KAFKA_CLUSTER_ID_FILE=/vagrant/kafka_cluster_id.txt
KAFKA_PASSWORD_FILE=/vagrant/password.txt
KAFKA_SERVICE=/etc/systemd/system/kafka.service


# install java jdk
wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list
sudo apt-get -y update
sudo apt-get -y install java-11-amazon-corretto-jdk

# populate /etc/hosts file
for i in `seq 1 ${NODE_COUNT}`; do
    echo "$NETWORK$((HOST_START+i)) node${i}.$DOMAIN" >> /etc/hosts
done

# create kafka user
sudo useradd kafka -G sudo -m -s /bin/bash
if [ ! -f $KAFKA_PASSWORD_FILE ]; then
  RANDOM_PW=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
  echo $RANDOM_PW > /vagrant/password.txt
else
  RANDOM_PW=$(cat $KAFKA_PASSWORD_FILE)
fi

echo "kafka:$RANDOM_PW" | sudo chpasswd

# download kafka if not already staged
if [ ! -f /tmp/$KAFKA_INSTALLER ]; then
  echo "Kafka installer not found"
  sudo -u kafka wget https://downloads.apache.org/kafka/${KAFKA_VERSION}/$KAFKA_INSTALLER -O /tmp/$KAFKA_INSTALLER
fi

# install kafka
sudo mkdir /opt/kafka
sudo mkdir /var/log/kafka
sudo chown kafka:kafka /opt/kafka /var/log/kafka
sudo -u kafka tar xzf /tmp/$KAFKA_INSTALLER -C /opt/kafka --strip 1

# create kafka server.properties in /opt/kafka/config/kraft
# build list of hosts for the controller.quorum.voters configuration parameter
for i in `seq 1 ${NODE_COUNT}`; do
  if [ $i -eq 1 ]; then
    CONTROLLER_QUORUM_VOTERS="$i@node$i.$DOMAIN:9093"
  else
    CONTROLLER_QUORUM_VOTERS="$CONTROLLER_QUORUM_VOTERS,$i@node$i.$DOMAIN:9093"
  fi
done

sudo -u kafka mv $KAFKA_SERVER_PROPERTIES $KAFKA_SERVER_PROPERTIES.old
if [ ! -f $KAFKA_SERVER_PROPERTIES ]; then
  sudo -u kafka cat > $KAFKA_SERVER_PROPERTIES <<EOF
process.roles=broker,controller
node.id=$NODE_ID
controller.quorum.voters=$CONTROLLER_QUORUM_VOTERS
listeners=PLAINTEXT://$HOSTNAME.$DOMAIN:9092,CONTROLLER://$HOSTNAME.$DOMAIN:9093
inter.broker.listener.name=PLAINTEXT
advertised.listeners=PLAINTEXT://$HOSTNAME.$DOMAIN:9092
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
log.dirs=/var/log/kafka/kraft-combined-logs
num.partitions=$((NODE_COUNT*2))
EOF
fi

# generate id for cluster
if [ $HOSTNAME == "node1" ]; then
  # if node1, create cluster id and save id so other vms can access
  sudo -u kafka /opt/kafka/bin/kafka-storage.sh random-uuid > $KAFKA_CLUSTER_ID_FILE 
  KAFKA_CLUSTER_ID=$(cat $KAFKA_CLUSTER_ID_FILE)
else
  # if any other node, get cluster id from cluster file in vagrant folder
  KAFKA_CLUSTER_ID=$(cat $KAFKA_CLUSTER_ID_FILE)
fi

# format storage dir
sudo -u kafka /opt/kafka/bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID -c /opt/kafka/config/kraft/server.properties

# create kafka service
if [ ! -f $KAFKA_SERVICE ]; then
  cat > $KAFKA_SERVICE <<EOF
[Unit]
Description=Kafka Service
Requires=network.target
After=network.target
StartLimitIntervalSec=300
StartLimitBurst=25

[Service]
Type=simple
User=kafka 
ExecStart=/bin/sh -c '/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties > /var/log/kafka/kafka.log 2>&1'
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
fi

# enable and start kafka service
sudo systemctl enable kafka
sudo systemctl start kafka


echo '##############################################################'
echo 'kafka user password is '$RANDOM_PW
