#!/bin/bash
images=(
    kube-apiserver:v1.15.3
    kube-controller-manager:v1.15.3
    kube-scheduler:v1.15.3
    kube-proxy:v1.15.3
    pause:3.1
    etcd-amd64:3.3.10
    etcd:3.3.10
    coredns:1.3.1

    pause-amd64:3.1

    kubernetes-dashboard-amd64:v1.10.0
    heapster-amd64:v1.5.4
    heapster-grafana-amd64:v5.0.4
    heapster-influxdb-amd64:v1.5.2
)

for imageName in ${images[@]} ; do
    docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
    docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName k8s.gcr.io/$imageName
done
