#!/bin/sh

mkdir -p /tmp/ISEMS

if ! [ -e /www/ISEMS ] 
	then 
	ln -s /tmp/ISEMS /www/ISEMS
 fi 

sleep 1

killall stty

while (true); do

cat /tmp/SERIAL_0 > /tmp/mppt.log  &
pid=$!                                                         
sleep 60                                                                                  
lua /usr/lib/lua/openmppt/main.lua 
kill $pid ;


LC=`wc -l /tmp/ISEMS/ffopenmppt.log | cut -d \  -f 1`

if [ $LC -ge 3660 ]
	then 
	gzip -f /tmp/ISEMS/ffopenmppt.log
	zcat /tmp/ISEMS/ffopenmppt.log.gz | tail -n 60 > /tmp/ffopenmppt.log
fi

done
