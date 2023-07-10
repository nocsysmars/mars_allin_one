# How to use mars in kubernetes?
## get docker images
currently, the mars k8s pods run on master node because of mount file from mars_allin_one conf directory, so just pull these images to master node is ok
```
docker pull nocsysmars/mars:master
docker pull nocsysmars/k8s-nginx:1.14.0
docker pull nocsysmars/logstash:7.5.2-oss
docker pull nocsysmars/elasticsearch:7.9.0-oss
docker pull busybox:latest
```
after download these images, you should **check these image names be consist with deployment**, otherwise rename them
## install yaml
cd mars_allin_one directory

edit kubernetes/mars-pvc.yaml, make sure PersistentVolume at you master node , in my envirement, this value is nodea, change it to your master node name.
edit kubernetes/mars-pvc.yaml make sure spec.local.path is availiable to store data.

The volume **hostPath.path only support absolute path,not relative path**, you should change mars-deployment.yaml, mars-logstash-deployment.yaml, mars-web-deployment.yaml these file hostPath.path value  to your mars_allin_one absolute path. or you will see "MountVolume.SetUp failed" errors

```
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

```
visit mars web: https://k8s_reset_ip:nodePort  
