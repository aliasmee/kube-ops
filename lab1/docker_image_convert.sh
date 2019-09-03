#!/bin/bash
# SCRIPT REF: https://juejin.im/post/5b8a4536e51d4538c545645c
KUBE_VERSION=1.15.3
images=(
    kube-apiserver:v$KUBE_VERSION
    kube-controller-manager:v$KUBE_VERSION
    kube-scheduler:v$KUBE_VERSION
    kube-proxy:v$KUBE_VERSION
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

