#!/bin/bash
service xinetd start
service filebeat restart
nginx -g 'daemon off;'
