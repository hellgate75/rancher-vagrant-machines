#!/bin/bash
# if [[ -z "$(sudo docker ps -a | grep rancher-db-server)" ]]; then
#   if [[ -e /root/rancher-server ]]; then
#     sudo rm -Rf /root/rancher-server
#   fi
#   sudo mkdir -p /root/rancher-server/db-data
#   # sudo mkdir -p /root/rancher-server/db-scripts
#   # sudo cp ./create-database.sql /root/rancher-server/db-scripts/
#   # sudo chmod 777 /root/rancher-server/db-scripts/create-database.sql
#   echo "Creating  rancher-db server container ..."
#   sudo docker run -d --hostname localhost --name rancher-db-server --restart=unless-stopped \
#   -e "MYSQL_ROOT_PASSWORD=rancheros" -e "MYSQL_DATABASE=cattle" -e "MYSQL_USER=cattle" -e "MYSQL_PASSWORD=cattle" \
#   -e "MYSQL_ROOT_HOST=localhost" -v /root/rancher-server/db-data:/var/lib/mysql \
#  -p 3306:3306 mysql/mysql-server:8.0
#   echo "Creating database schema ..."
#   # sudo docker exec rancher-db-server yum install -y mysql-server
#   sudo docker exec rancher-db-server useradd --create-home --home-dir=/home/cattle --password=cattle --shell=/bin/bash cattle
#   sudo docker cp ./create-database.sql rancher-db-server:/root/create-database.sql
#   sudo docker exec -it rancher-db-server /bin/bash -c "mysql --user=root --password=rancheros < /root/create-database.sql"
#   echo "Database created  ..."
#   # sudo docker log -f  rancher-db-server
# else
#   echo "Docker image racher-server database (rancher-db-server) already exists ..."
# fi
if ! [[ -z "$(sudo docker ps -a | grep rancher-server)" ]]; then
  echo "Destroying existing  rancher-server container ..."
  sudo docker stop rancher-server
  sudo docker rm rancher-server
  echo "Now we proceed with the rancher server installation ..."
else
  echo "Ready to install racher-server..."
fi
# sudo docker run -d --hostname localhost --link rancher-db-server:rancher-db --name rancher-server --privileged --restart=unless-stopped \
# -p 8080:8080 rancher/server --db-host rancher-db --db-port 3306 --db-user cattle --db-pass cattle --db-name cattle
echo "Script parameters : $1"
if [[ -e /root/rancher-server ]] && [[ "recreate" == "$1" ]]; then
  echo "Removing rancher server db local volume data ..."
  sudo rm -Rf /root/rancher-server
fi
sudo mkdir -p /root/rancher-server/db-data
sudo docker run -d --hostname localhost --name rancher-server --privileged --restart=unless-stopped \
-v /root/rancher-server/db-data:/var/lib/mysql -p 8080:8080 rancher/server

sudo docker logs -f rancher-server
