#!/bin/bash

# (c) 2008, Roman Ovchinnikov
# coolthecold@gmail.com

DATE_CMD="date +%s"
TIME_INTERVAL=1

ARGS=2
if [[ $# -ne "$ARGS"  ]]
then
    echo "usage: `basename $0` <url> [cookie file]"
    echo "for example, static file: `basename $0` http://ban02.banners.mail.ru/js/show.js cookie.txt"
    echo "or dynamic file: `basename $0` http://ban02.banners.mail.ru/js/1000.js cookie.txt"
    echo "set cookie file to NO to disable cookieng"
    echo "---"
    echo "Hint: use smth like 'cat show_flash.nginx_banners.txt|cut -f 2 -d \" \" |cut -f 2 -d \":\"|sort -n|uniq -c' to view largest times sets "
    exit 1
            
fi

URL=$1
for i in `seq 1 172800`
do
curdate=`$DATE_CMD`
if [[ "x$2" = "xNO" ]]
then
    CURL_DATA=`curl -o /dev/null --compress -w '%{time_total} %{time_connect}\n' $URL 2>/dev/null`
else
    CURL_DATA=`curl -b cookie.txt --compress -o /dev/null -w '%{time_total} %{time_connect}\n' $URL 2>/dev/null`
fi
if [[ "x$CURL_DATA" = "x" ]]
then
    #empty curl data, do we have curl installed?
    echo "no data from curl, is it installed? try \"sudo apt-get install curl\" to fix this";exit 1
fi
#echo "curl data"
#echo "$CURL_DATA"

RESP_DATA=`echo "$CURL_DATA"|tail -n 1`

#echo "resp data"
#echo "$RESP_DATA"

TOTAL_TIME=`echo $RESP_DATA|awk '{print $1}'`
CONNECT_TIME=`echo $RESP_DATA|awk '{print $2}'`
echo "time:$curdate ttime:$TOTAL_TIME conntime:$CONNECT_TIME"
sleep $TIME_INTERVAL
done