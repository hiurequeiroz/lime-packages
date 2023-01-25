#!/bin/sh

mkdir -p /tmp/ffomppt


while (true); do

wget -q http://hiure-test/csv.log -O /tmp/ffomppt/ffomppt.csv
pid=$!                                                         
sleep 60                                                                                  
lua /usr/lib/lua/ffomppt/main.lua 
kill $pid ;


LC=`wc -l /tmp/ffomppt/ffomppt.csv | cut -d \  -f 1`

if [ $LC -ge 3660 ]
	then 
	gzip -f /tmp/ffomppt/ffomppt.csv
	zcat /tmp/ffomppt/ffomppt.csv.gz | tail -n 60 > /tmp/ffomppt.log
fi

done
