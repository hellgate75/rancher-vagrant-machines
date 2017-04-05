#!/bin/sh
cd rancheros-server
vagrant up
sleep 15
cd ../rancheros-slave-1
vagrant up
sleep 15
cd ../rancheros-slave-2
vagrant up
sleep 15
cd ../rancheros-slave-3
vagrant up
