#!/bin/bash
vzconfig=vzcreate.conf

ARGS=1
if [[ $# -ne "$ARGS"  ]]
then
    echo "usage: `basename $0` <ipaddress>>"
    echo "for example: `basename $0` 10.10.10.5"
    exit 1

fi

if [ -r $vzconfig ]; then 
    . $vzconfig
else
    echo "failed to read config $vzconfig"
    exit 2
fi
nsstring=""
for i in $nameservers;do
    #echo "nameserver is $i"
    nsstring="$nsstring --nameserver $i"
done
#echo "my ip is $myip"

if [ -z "$nsstring" ];then echo "nameservers list is empty!";exit 2;fi
if [ -z "$myip" ];then echo "myip is empty!";exit 2;fi
	    
iptables -t nat -A POSTROUTING -s $1 -o eth0 -j SNAT --to $myip
