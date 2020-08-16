#!/bin/bash

controller_ip=nocsystestlab1.ddns.net
user=karaf:karaf

a=$(curl -u $user  -X GET --header 'Accept: application/json' $controller_ip:8181/mars/v1/applications/org.onosproject.fwd)

#ther is no connection
if [ "$a" == "" ]; then
 echo "Mars disconnect, restart mars wait 30s"
 docker restart mars
 sleep 30

 count=0 
 while true
 do
   count=$((count + 1))
   b=$(curl -u $user  -X GET --header 'Accept: application/json' $controller_ip:8181/mars/v1/applications/org.onosproject.fwd)
   if [ "grep ACTIVE $b" == "" ];then
      echo "FWD is still not ACTIVE, keep wait"
   else
      exit 1
   fi   

   if [ $((count %3)) == 0 ];then
       echo "restart mars again due to wait to long"
       docker restart mars
       sleep 30
   fi
   sleep 10
 done

fi

#check fwd is activate or not, do mars restart
if [ "grep ACTIVE $a" == "" ];then
  echo "FWD is not ACTIVE"
  docker restart mars
fi

echo "finish check"
