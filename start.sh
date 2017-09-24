#!/bin/sh

install_dir=/alidata/www/test2/node/51fetch_all

ps -ef | grep index.coffee | awk '{print $2}' | xargs kill -9
ps -ef | grep ipproxy_server.coffee | awk '{print $2}' | xargs kill -9

rm -rf logs/*

local_ip=$(ifconfig eth1 | grep inet | cut -d':' -f 2 | cut -d ' ' -f1)

if [ "$local_ip"x = "121.41.173.223"x ]; then
    sleep 5
    forever start --minUptime 60000 --spinSleepTime 60000 -l $install_dir/logs/ipproxy.forever.log -e $install_dir/logs/ipproxy.err.log -o $install_dir/logs/ipproxy.out.log -c coffee src/ipproxy_server.coffee
fi

forever start --minUptime 60000 --spinSleepTime 60000 -l $install_dir/logs/index.forever.log -e $install_dir/logs/index.err.log -o $install_dir/logs/index.out.log -c coffee index.coffee ecmall51_2 "$local_ip" false api
