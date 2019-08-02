#!/bin/bash
service filebeat restart
nginx -g 'daemon off;'
