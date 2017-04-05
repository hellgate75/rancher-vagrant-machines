#!/bin/sh
cd rancheros-slave-1
vagrant reload
sleep 15
cd ../rancheros-slave-2
vagrant reload
sleep 15
cd ../rancheros-slave-3
vagrant reload
