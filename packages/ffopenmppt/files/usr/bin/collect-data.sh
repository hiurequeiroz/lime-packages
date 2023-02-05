#!/bin/sh

mkdir -p /tmp/ffomppt


while (true); do

wget -q http://hiure-test/csv.log -O /tmp/ffomppt/ffomppt.csv
# TODO
# using hiure-test how exemple but need to automatize utilising wget in each clinte and see a unic pattern that came from omppt

# just to check
# I dont know if need this pid thing, let here for a while just to remember
# pid=$!                                                         
# sleep 60                                                                                  
# lua /usr/lib/lua/ffomppt/main.lua 
# kill $pid ;


# This is for take care with the size of the file
LC=`wc -l /tmp/ffomppt/ffomppt.csv | cut -d \  -f 1`

if [ $LC -ge 3660 ]
	then 
	gzip -f /tmp/ffomppt/ffomppt.csv
	zcat /tmp/ffomppt/ffomppt.csv.gz | tail -n 60 > /tmp/ffomppt.log
fi

done
