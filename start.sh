#!/bin/sh

kill $(forever list | grep coffee | cut -d ' ' -f14)

rm -rf logs/*

localip=$(ifconfig eth1 | grep inet | cut -d':' -f 2 | cut -d ' ' -f1)

forever start --minUptime 60000 --spinSleepTime 60000 -l /alidata/www/test2/node/51fetch_all/logs/forever.log -e ./logs/err.log -o ./logs/gz.log -c coffee index.coffee ecmall51_2 "$localip" false api
