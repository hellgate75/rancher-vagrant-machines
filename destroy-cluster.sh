#!/bin/sh
cd rancheros-slave-1
vagrant destroy -f
cd ../rancheros-slave-2
vagrant destroy -f
cd ../rancheros-slave-3
vagrant destroy -f
