#!/bin/bash

curl -XPUT  "0.0.0.0:9200/_template/default_template?pretty" -H 'Content-Type: application/json' -d'{"index_patterns": ["*"], "settings" : {"number_of_shards" : 2,"number_of_replicas" : 0}}'
