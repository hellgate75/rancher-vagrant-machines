#!/bin/bash
sudo apt-get update  > /dev/null 2>&1
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common > /dev/null 2>&1
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update > /dev/null 2>&1
sudo apt-get install docker-ce > /dev/null 2>&1
udo apt-get -y autoremove > /dev/null 2>&1 && \
sudo apt-get -y clean > /dev/null 2>&1 && \
sudo rm -Rf /var/lib/apt/lists/*
sudo usermod -aG docker rancher
sudo usermod -aG docker root
