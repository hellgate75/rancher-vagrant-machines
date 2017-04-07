#!/bin/sh
docker-machine create -d virtualbox --virtualbox-boot2docker-url https://github.com/rancher/os/releases/download/v0.9.0/rancheros.iso test-rancher
docker-machine env test-rancher
