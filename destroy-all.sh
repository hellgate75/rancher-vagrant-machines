#!/bin/sh
cd rancheros-server
vagrant destroy -f
cd ../rancheros-slave-1
vagrant destroy -f
cd ../rancheros-slave-2
vagrant destroy -f
cd ../rancheros-slave-3
vagrant destroy -f
