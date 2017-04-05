#!/bin/sh
docker ps -a -q | xargs docker rm -f && docker volume ls -q | xargs docker volume rm 
