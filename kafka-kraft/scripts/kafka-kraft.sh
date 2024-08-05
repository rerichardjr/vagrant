#!/bin/bash

set -euxo pipefail

KAFKA_INSTALLER=kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
KAFKA_SERVER_PROPERTIES=${INSTALL_FOLDER}/config/kraft/server.properties
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

# create user
sudo useradd ${RUN_AS_USER} -G sudo -m -s /bin/bash
if [ ! -f $KAFKA_PASSWORD_FILE ]; then
  RANDOM_PW=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
  echo $RANDOM_PW > $KAFKA_PASSWORD_FILE
fi

RANDOM_PW=$(cat $KAFKA_PASSWORD_FILE)
echo "$RUN_AS_USER:$RANDOM_PW" | sudo chpasswd

# download kafka if not already staged
if [ ! -f /tmp/$KAFKA_INSTALLER ]; then
  echo "Kafka installer not found"
  sudo -u ${RUN_AS_USER} wget https://downloads.apache.org/kafka/${KAFKA_VERSION}/$KAFKA_INSTALLER -O /tmp/$KAFKA_INSTALLER
fi

# install kafka
sudo mkdir ${INSTALL_FOLDER} ${LOG_FOLDER}
sudo chown ${RUN_AS_USER}:${RUN_AS_USER} ${INSTALL_FOLDER} ${LOG_FOLDER}
sudo -u ${RUN_AS_USER} tar xzf /tmp/$KAFKA_INSTALLER -C ${INSTALL_FOLDER} --strip 1

# create kafka server.properties
# build list of hosts for the controller.quorum.voters configuration parameter
for i in `seq 1 ${NODE_COUNT}`; do
  if [ $i -eq 1 ]; then
    CONTROLLER_QUORUM_VOTERS="$i@node$i.$DOMAIN:9093"
  else
    CONTROLLER_QUORUM_VOTERS="$CONTROLLER_QUORUM_VOTERS,$i@node$i.$DOMAIN:9093"
  fi
done

sudo -u ${RUN_AS_USER} mv $KAFKA_SERVER_PROPERTIES $KAFKA_SERVER_PROPERTIES.orig
if [ ! -f $KAFKA_SERVER_PROPERTIES ]; then
  sudo -u ${RUN_AS_USER} cat > $KAFKA_SERVER_PROPERTIES <<EOF
process.roles=broker,controller
node.id=$NODE_ID
controller.quorum.voters=$CONTROLLER_QUORUM_VOTERS
listeners=PLAINTEXT://$HOSTNAME.$DOMAIN:9092,CONTROLLER://$HOSTNAME.$DOMAIN:9093
inter.broker.listener.name=PLAINTEXT
advertised.listeners=PLAINTEXT://$HOSTNAME.$DOMAIN:9092
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
log.dirs=${LOG_FOLDER}/kraft-combined-logs
num.partitions=3
auto.create.topics.enable=false
EOF
fi

# generate id for cluster
if [ $HOSTNAME == "node1" ]; then
  # if node1, create cluster id and save id so other vms can access
  sudo -u ${RUN_AS_USER} ${INSTALL_FOLDER}/bin/kafka-storage.sh random-uuid > $KAFKA_CLUSTER_ID_FILE 
fi

KAFKA_CLUSTER_ID=$(cat $KAFKA_CLUSTER_ID_FILE)
sudo -u ${RUN_AS_USER} ${INSTALL_FOLDER}/bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID -c ${INSTALL_FOLDER}/config/kraft/server.properties

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
ExecStart=/bin/sh -c '${INSTALL_FOLDER}/bin/kafka-server-start.sh ${INSTALL_FOLDER}/config/kraft/server.properties > ${LOG_FOLDER}/kafka.log 2>&1'
ExecStop=${INSTALL_FOLDER}/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
fi

# enable and start kafka service
sudo systemctl enable kafka
sudo systemctl start kafka

# add install folder path to vagrant users env
echo 'export PATH="$PATH:'${INSTALL_FOLDER}'/bin"' >> .bashrc

echo '##############################################################'
echo  ${RUN_AS_USER}' user password is '$RANDOM_PW
