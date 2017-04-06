#!/bin/bash
sudo ip addr del $(ifconfig eth0 | grep 'inet '|awk 'BEGIN {FS=OFS= " "}{print $2}')/24 dev eth0 > /root/net.restart.log

if [[ -z "$(sudo brctl show  | grep docker1 | grep eth1)"]]; then
   sudo brctl addif docker1 eth1
fi
sudo system-docker restart network >> /root/net.restart.log
rm -f /home/rancher/restart-net.sh
