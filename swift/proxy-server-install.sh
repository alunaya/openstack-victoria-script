#!/bin/bash

clear

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


