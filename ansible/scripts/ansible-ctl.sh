#!/bin/bash

set -euxo pipefail

# install ansible
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get -y update
sudo apt-get -y install ansible

# create ansible user
sudo useradd ansible -G sudo -m -s /bin/bash
RANDOM_PW=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
echo "ansible:$RANDOM_PW" | sudo chpasswd

# create ssh keys for ansible user
sudo -u ansible ssh-keygen -t ed25519 -N '' -f /home/ansible/.ssh/id_ed25519 <<< y

# prompt user to copy ssh keys to servers that will be managed with ansible
echo '##############################################################'
echo 'ansible user password is ' $RANDOM_PW
echo 'Copy the ssh keys to each server using the following example:'
echo 'ssh-copy-id -i ~/.ssh/id_ed25519.pub ansible@192.168.50.6'
