#!/bin/sh
sudo docker run -d --privileged -e CATTLE_AGENT_IP="192.168.50.114" --add-host=rancher:192.168.0.101  --restart=unless-stopped -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.1.3 http://rancher:8080/v1/scripts/FA35F29823F5BC6F1CEB:1485655200000:vbJ1Y3GyoEo0dpBEoNtiLIpeauQ
