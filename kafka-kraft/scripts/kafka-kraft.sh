#!/bin/bash

set -euxo pipefail

KAFKA_INSTALLER=kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
KAFKA_SERVICE=/etc/systemd/system/kafka.service

# install java jdk
wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list
sudo apt-get -y update
sudo apt-get -y install java-11-amazon-corretto-jdk

# create kafka user
sudo useradd kafka -G sudo -m -s /bin/bash
RANDOM_PW=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
echo "kafka:$RANDOM_PW" | sudo chpasswd

# download kafka if not already staged
if [ ! -f /tmp/$KAFKA_INSTALLER ]; then
  echo "Kafka installer not found"
  sudo -u kafka wget https://downloads.apache.org/kafka/${KAFKA_VERSION}/$KAFKA_INSTALLER -O /tmp/$KAFKA_INSTALLER
fi

# install kafka
sudo -u kafka mkdir /home/kafka/kafka
sudo -u kafka tar xzf /tmp/$KAFKA_INSTALLER -C /home/kafka/kafka --strip 1

# generate id for cluster and format storage dir
sudo -u kafka /home/kafka/kafka/bin/kafka-storage.sh format -t $(sudo -u kafka /home/kafka/kafka/bin/kafka-storage.sh random-uuid) -c /home/kafka/kafka/config/kraft/server.properties

# create kafka service
if [ ! -f $KAFKA_SERVICE ]; then
  cat > $KAFKA_SERVICE <<EOF
[Service]
Type=simple
User=kafka
ExecStart=/bin/sh -c '/home/kafka/kafka/bin/kafka-server-start.sh /home/kafka/kafka/config/kraft/server.properties > /home/kafka/kafka/kafka.log 2>&1'
ExecStop=/home/kafka/kafka/bin/kafka-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF
fi

sudo systemctl enable kafka
sudo systemctl start kafka

echo '##############################################################'
echo 'kafka user password is ' $RANDOM_PW
