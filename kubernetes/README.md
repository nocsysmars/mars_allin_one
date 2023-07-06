# How to use mars in kubernetes?
```
cd mars_allin_one

edit kubernetes/mars-pvc.yaml, make sure PersistentVolume at you master node , in my envirement, this value is nodea, change it to your master node name.
edit kubernetes/mars-pvc.yaml make sure spec.local.path is availiable to store data.

run the follow command:
kubectl apply -f kubernetes/mars-pvc.yaml
kubectl apply -f kubernetes/mars-elasticsearch-deployment.yaml
kubectl apply -f kubernetes/mars-logstash-deployment.yaml
kubectl apply -f kubernetes/mars-deployment.yaml
kubectl apply -f kubernetes/mars-web-deployment.yaml
kubectl apply -f kubernetes/mars-service.yaml

check mars-web pod is running:
    kubelet get pod
, then get mars-web service nodePort:
    kubelet get svc mars-web

 visit mars web: https://k8s_reset_ip:nodePort   
```