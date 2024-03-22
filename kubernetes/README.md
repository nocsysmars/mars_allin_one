# How to use mars in kubernetes?
## get docker images
```
docker pull acctonmars/mars:master
docker pull acctonmars/nginx:1.14.0
docker pull acctonmars/logstash:7.5.2-oss
docker pull acctonmars/elasticsearch:7.9.0-oss
docker pull busybox:1.28.4
```
after download these images, you should **check these image names be consist with deployment**, otherwise rename them
## install yaml
cd mars_allin_one directory

edit kubernetes/mars-pvc.yaml, make sure PersistentVolume at you master node , in my envirement, this value is nodea, change it to your master node name.
edit kubernetes/mars-pvc.yaml make sure spec.local.path is availiable to store data.
```
run the follow command:
kubectl apply -f kubernetes/mars-setup.yaml
kubectl apply -f kubernetes/mars-configmap.yaml
kubectl apply -f kubernetes/mars-pvc.yaml
kubectl apply -f kubernetes/mars-secret.yaml
kubectl apply -f kubernetes/mars-elasticsearch-deployment.yaml
kubectl apply -f kubernetes/mars-logstash-deployment.yaml
kubectl apply -f kubernetes/mars-deployment.yaml
kubectl apply -f kubernetes/mars-web-deployment.yaml
kubectl apply -f kubernetes/mars-service.yaml
```
check mars-web pod is running:
```
kubelet get pod
```    
, then get mars-web service nodePort:
```
kubelet get svc mars-web
```
visit mars web: https://k8s_reset_ip:nodePort  
