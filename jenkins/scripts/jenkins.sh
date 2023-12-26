#!/bin/bash

set -euxo pipefail

sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
sudo echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get -y update
sudo apt-get -y install fontconfig openjdk-17-jre
sudo apt-get -y install jenkins

#display bridged IP
echo "################  Machine bridged IP  ##################"
sudo ip address show dev eth1 | awk -F'[ /]' '/inet /{print $6}'

#display jenkins admin password
echo "################  Admin password  ######################"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword