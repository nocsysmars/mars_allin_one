#!/bin/bash

docker save  mars:master -o mars_master.tar
docker save  nginx:1.14.0 -o nginx.tar
docker save  logstash:7.5.2-oss -o logstash.tar
docker save  elasticsearch:7.9.0 -o elasticsearch.tar
