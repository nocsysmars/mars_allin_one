#!/bin/bash
while true
do

a=$(docker ps -a |grep mars)
if [ -z "$a" ]; then
   echo "docker-compose up -d"
   cd $PWD
   docker-compose up -d
else
  a=$(docker ps |grep mars)

  if [ -z "$a" ]; then
    echo "restart mars"
    docker restart mars
  fi
fi

sleep 10

done

