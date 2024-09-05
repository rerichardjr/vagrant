#!/bin/bash

set -euxo pipefail

APT_STORE=/var/cache/apt/archives
PASSWORD_FILE=/vagrant/password.txt

sudo apt-get update && sudo apt-get -y install pwgen

if ! id -u ${RUN_AS_USER} >/dev/null 2>&1; then
  sudo useradd ${RUN_AS_USER} -G sudo -M -s /bin/bash
  if [ ! -f $PASSWORD_FILE ]; then
    RANDOM_PW=$(pwgen -0 -n 10 1; echo)
    echo $RANDOM_PW > $PASSWORD_FILE
  fi
  RANDOM_PW=$(cat $PASSWORD_FILE)
  echo "$RUN_AS_USER:$RANDOM_PW" | sudo chpasswd
fi

sudo apt-get update && sudo apt-get -y install lsb-release ca-certificates curl gnupg2
curl -o- https://artifacts.opensearch.org/publickeys/opensearch.pgp | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring
echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/apt stable main" | sudo tee /etc/apt/sources.list.d/opensearch-2.x.list
echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch-dashboards/2.x/apt stable main" | sudo tee /etc/apt/sources.list.d/opensearch-dashboards-2.x.list
sudo apt-get update
sudo env OPENSEARCH_INITIAL_ADMIN_PASSWORD=$RANDOM_PW apt-get install opensearch=$OPENSEARCH_VERSION opensearch-dashboards=$OPENSEARCH_VERSION

echo 'server.host: '${NETWORK_IP} >> /etc/opensearch-dashboards/opensearch_dashboards.yml

sudo systemctl enable opensearch
sudo systemctl start opensearch
sudo systemctl enable opensearch-dashboards
sudo systemctl start opensearch-dashboards