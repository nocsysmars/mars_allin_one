#!/bin/bash

echo "This script should enter controller IP and how many hours you would like to detect memory.
During the memory detection if current heap size has great than threshold heap which is heap maximum size * 0.75.
It will record the information into memory_detector.log file. Note: The polling interval is 1 sec. "

echo ""
if [ $# -ne 2 ]; 
    then echo "memory_detector <ctrl IP> <log n hours>"
    exit
fi

curl -s -i -XPOST http://$1:8181/mars/useraccount/v1/login --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{"user_name":"karaf", "password":"karaf"}' > session_temp

token=$(cat session_temp |grep MARS_G_SESSION_ID:|cut -d ":"  -f 2|tr -d '[:space:]')

if [[ $token  == "" ]];
    then echo "can not access controller"
    exit
fi


duration=$(($2 * 3600))

end_time=$((SECONDS + duration))

while [ $SECONDS -lt $end_time ]; do
    HEAP_CURRENT=$(curl -s -H "Cookie: marsGSessionId=$token" -XGET http://$1:8181/mars/v1/system/systemInfo|jq -r '.heapMem.current')
    HEAP_MAX=$(curl -s -H "Cookie: marsGSessionId=$token" -XGET http://$1:8181/mars/v1/system/systemInfo|jq -r '.heapMem.max')
    ALERT_THRESHOLD=$(printf "%.0f" $(echo "$HEAP_MAX * 0.75" | bc))

    // convert data into Megabyte
    HEAP_CURRENT_MB=$((HEAP_CURRENT / (1024 * 1024)))
    HEAP_MAX_MB=$((HEAP_MAX / (1024 * 1024)))
    ALERT_THRESHOLD_MB=$((ALERT_THRESHOLD / (1024 * 1024)))

    date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "Current date: $date, Current Heap: $HEAP_CURRENT_MB MB, Max Heap: $HEAP_MAX_MB MB, Threshold Heap: $ALERT_THRESHOLD_MB MB"
    if [ $HEAP_CURRENT -gt $ALERT_THRESHOLD ]
    then
        echo "Current date: $date, Current Heap: $HEAP_CURRENT_MB MB, Max Heap: $HEAP_MAX_MB MB, Threshold Heap: $ALERT_THRESHOLD_MB MB" >> memory_detector.log
    fi
    sleep 1
done

