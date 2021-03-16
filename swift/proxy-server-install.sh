#!/bin/bash

clear

# Get config parameter
while true
do
  read -p "Enter listening port for proxy:" port
  if [ $port -lt 1 | $port -gt 65535 ]; then
    echo "Invalid port"
    else
    break
  fi
done

while true
do
  read -p "Enter proxy user:" user
  if [ -z "$user" ]; then
    echo "Invalid input"
    else
    break
  fi
done

while true
do
  read -p "Enter config directory:" configDir
  if [ ! -d "$configDir" ]; then
    echo "This path doesn't exist or doesn't point to a directory"
    else
    break
  fi
done

# update repository
apt update

# add deadsnakes repo and install python 3
apt install -y software-properties-common
yes "" | add-apt-repository ppa:deadsnakes/ppa
apt install python3

# install swift and python dependencies
yes "" | apt-get install swift swift-proxy python-swiftclient \
  python-keystoneclient python-keystonemiddleware \
  memcached


