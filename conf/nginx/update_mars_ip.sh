#! /bin/bash

#take mars k8s service dns as mars ip
sed -i 's/127.0.0.1/mars.default.svc.cluster.local/g' /etc/nginx/nginx.conf
nginx -g "daemon off;"