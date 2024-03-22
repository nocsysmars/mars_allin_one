#! /bin/bash

#take mars k8s service dns as mars ip
sed -i 's/127.0.0.1/mars.accton-mars.svc.cluster.local/g' /etc/nginx/nginx.conf
sed -i 's/http:\/\/localhost:8443/http:\/\/mars.accton-mars.svc.cluster.local:8443/g' /etc/nginx/nginx.conf
sed -i 's/http:\/\/localhost:3233/http:\/\/mars.accton-mars.svc.cluster.local:3233/g' /etc/nginx/nginx.conf

sed -i 's/localhost:5044/logstash.accton-mars.svc.cluster.local:5044/g' /etc/filebeat/filebeat.yml

service xinetd start
service filebeat restart
nginx -g "daemon off;"