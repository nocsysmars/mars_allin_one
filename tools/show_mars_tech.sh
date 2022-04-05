#!/bin/bash

if [ $# -ne 2 ]; 
    then echo "show_mars_tech <ctrl IP> <log n hours>"
    exit
fi

echo $1

docker logs mars &> docker_logs

curl  -i -XPOST http://$1/mars/useraccount/v1/login --header 'Content-Type: application/json' --header 'Accept: application/json' -d  '{"user_name":"karaf", "password":"karaf"}' > session_temp

token=$(cat session_temp |grep MARS_G_SESSION_ID:|cut -d ":"  -f 2|tr -d '[:space:]')

if [[ $token  == "" ]];
    then echo "can not access controller"
    exit
fi

curl -i  -H "Cookie: marsGSessionId=$token" -XGET http://$1:8181/mars/utility/v1/version 1> ctrl_version.log
curl -i  -H "Cookie: marsGSessionId=$token" -XGET http://$1:8181/mars/v1/system/systemInfo 1> ctrl_hostinfo.log
curl -i  -H "Cookie: marsGSessionId=$token" -XGET -k https://$1/build.json 1> web_version.log
curl -i  -H "Cookie: marsGSessionId=$token" -XGET http://$1:8181/mars/utility/logs/v1/controller/files/karaf_error.log 1> karaf_error.log
curl -i  -H "Cookie: marsGSessionId=$token" -XGET http://$1:8181/mars/utility/logs/v1/controller/files/karaf.log 1> karaf.log
for i in $(seq 1 5);
do
    echo $i
    curl -i  -H "Cookie: marsGSessionId=$token" -XGET http://$1:8181/mars/utility/logs/v1/controller/files/karaf.log.$i 1> karaf.log.$i
done

#from elasticsearch
off_utc=$(($2+8))
timestamp=$(date -d "$off_utc hours ago" +%Y-%m-%dT%H:%M:%S.0000Z)
echo $timestamp
curl -i  -H "Cookie: marsGSessionId=$token" -XGET http://$1:8181/mars/utility/logs/v1/controller?start=$timestamp\&number=2000\&match=\&source=/root/onos/apache-karaf-3.0.8/data/log/karaf.log 1> karaf_from_es.log
