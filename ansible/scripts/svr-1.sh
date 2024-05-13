#!/bin/bash

set -euxo pipefail

# create ansible user
sudo useradd ansible -G sudo -m -s /bin/bash
RANDOM_PW=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
echo "ansible:$RANDOM_PW" | sudo chpasswd

echo '##############################################################'
echo 'ansible user password is ' $RANDOM_PW