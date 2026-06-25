#!/bin/bash
service xinetd start
rm -f /var/lib/filebeat/registry
service filebeat restart
nginx -g 'daemon off;'
