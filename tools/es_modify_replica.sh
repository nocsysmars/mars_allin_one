#!/bin/bash

curl -XGET 0.0.0.0:9200/_cat/indices \
| awk '{print $3}' \
| while read i; \
    do curl -XPUT -H "Content-Type: application/json" http://0.0.0.0:9200/$i/_settings  -d '{"number_of_replicas" : 0}'; \
  done
