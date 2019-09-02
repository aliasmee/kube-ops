### 初始化集群基础信息

* 主机名
```bash
ansible "k8s-m1" -m shell -a "hostnamectl set-hostname k8s-m1" -i k8s-hosts.ini
ansible "k8s-m2" -m shell -a "hostnamectl set-hostname k8s-m2" -i k8s-hosts.ini
ansible "k8s-m3" -m shell -a "hostnamectl set-hostname k8s-m3" -i k8s-hosts.ini
```
* IP hosts & Disable swap for kubectl
```bash
ansible-playbook update_hosts.yml -i k8s-hosts.ini
```

### Install Docker
```bash
ansible-playbook -i k8s-hosts.ini 02-install_docker.yml
```

### Install kubelet kubeadm
```bash
ansible-playbook -i k8s-hosts.ini 03-install_kubelet.yml
```

### Setup & install haproxy

* download haproxy roles
```bash
ansible-galaxy install geerlingguy.haproxy -p .
```

* setup hostname
```bash
ansible "haproxy*" -m shell -a "hostnamectl set-hostname haproxy1" -i k8s-hosts.ini
```

* install haproxy to target hosts
```bash
ansible-playbook -i k8s-hosts.ini 04-install_haproxy.yml
```

### Use kubeadm init cluster master control plan

* Init first master
```bash
ansible-playbook 05-config-master.yml -i k8s-hosts.ini
```

TIPS: 在运行kubeadmin init 之后，会输出加入Control plan节点以及 加入Worker 节点的命令及token。注意，输出的token有效期是24h!
下一节将说下如何重新生成token（因为我第三天才开始继续搞这个... 🤦‍♂️）

* Setup kubeconfig
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
OR

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

* Install pod network (flannel)
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml
```

TIPS: 在安装cni Pod网络后，coredns才会正常工作，一旦coredns的状态由pending 转换为running之后，那么就可以执行下一步加入其它节点了。如果你只需要单个master节点，此时的集群就已经可用了，可以跳过join control plan 那一步。直接去worker节点上运行加入worker节点的命令


### Join other Control-plan(Master) & Worker-node

#### Token expire join method (Master)

* Recreate new token
```bash
[root@k8s-m1 ~]# kubeadm token create
dvj9of.s9wfiznwv53007ly
[root@k8s-m1 ~]# kubeadm token list
TOKEN                     TTL         EXPIRES                     USAGES                   DESCRIPTION                                           EXTRA GROUPS
894n1s.hbspnuatwopjm1go   <invalid>   2019-09-01T17:30:50+08:00   authentication,signing   <none>                                                system:bootstrappers:kubeadm:default-node-token
cn983g.g06anmco5imo80ge   <invalid>   2019-08-31T19:30:50+08:00   <none>                   Proxy for managing TTL for the kubeadm-certs secret   <none>
dvj9of.s9wfiznwv53007ly   23h         2019-09-03T13:04:20+08:00   authentication,signing   <none>                                                system:bootstrappers:kubeadm:default-node-token
```

* 使用刚刚重新生成的token,在第二个控制节点上运行时出现以下错误:
```bash
[root@k8s-m2 ~]# kubeadm join haproxy1:8443 --token dvj9of.s9wfiznwv53007ly --discovery-token-ca-cert-hash sha256:0329f41276e2336e32053d284f9dbcaca8fe1b12b37b63c9146851982fff2a52 --control-plane --certificate-key 430ff0f867d2660654af1c0b77df23c5886b6cdc9c7ac3e245f9952d3a9a40b7
[preflight] Running pre-flight checks
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
	[WARNING SystemVerification]: this Docker version is not on the list of validated versions: 19.03.0. Latest validated version: 18.09
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks before initializing the new control plane instance
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[download-certs] Downloading the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
error execution phase control-plane-prepare/download-certs: error downloading certs: error downloading the secret: Secret "kubeadm-certs" was not found in the "kube-system" Namespace. This Secret might have expired. Please, run `kubeadm init phase upload-certs --upload-certs` on a control plane to generate a new one
```

* 按照这个FYI提示的命令，在第一个控制节点k8s-m1运行之后，得到以下输出:
```bash
[root@k8s-m1 ~]# kubeadm init phase upload-certs --upload-certs
W0902 13:19:48.926062  123596 version.go:98] could not fetch a Kubernetes version from the internet: unable to get URL "https://dl.k8s.io/release/stable-1.txt": Get https://dl.k8s.io/release/stable-1.txt: net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)
W0902 13:19:48.926320  123596 version.go:99] falling back to the local client version: v1.15.3
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
1aa5c6bdf5691eb4e92ed7d87d97f55b0c8f2614e2bda9b9644f62bf1b4f6548
```

TIPS: certificate key 有效期只有2小时

* 之后在第二个控制节点k8s-m2上，以新的cert key `1aa5c6bdf5691eb4e92ed7d87d97f55b0c8f2614e2bda9b9644f62bf1b4f6548` 重新运行join命令：
```bash
[root@k8s-m2 ~]# kubeadm join haproxy1:8443 --token dvj9of.s9wfiznwv53007ly --discovery-token-ca-cert-hash sha256:0329f41276e2336e32053d284f9dbcaca8fe1b12b37b63c9146851982fff2a52 --control-plane --certificate-key 1aa5c6bdf5691eb4e92ed7d87d97f55b0c8f2614e2bda9b9644f62bf1b4f6548
[preflight] Running pre-flight checks
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
	[WARNING SystemVerification]: this Docker version is not on the list of validated versions: 19.03.0. Latest validated version: 18.09
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks before initializing the new control plane instance
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[download-certs] Downloading the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [k8s-m2 localhost] and IPs [172.16.193.72 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [k8s-m2 localhost] and IPs [172.16.193.72 127.0.0.1 ::1]
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [k8s-m2 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local haproxy1] and IPs [10.96.0.1 172.16.193.72]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Valid certificates and keys now exist in "/etc/kubernetes/pki"
[certs] Using the existing "sa" key
[kubeconfig] Generating kubeconfig files
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[endpoint] WARNING: port specified in controlPlaneEndpoint overrides bindPort in the controlplane address
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[check-etcd] Checking that the etcd cluster is healthy
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.15" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...
[etcd] Announced new etcd member joining to the existing etcd cluster
[etcd] Wrote Static Pod manifest for a local etcd member to "/etc/kubernetes/manifests/etcd.yaml"
[etcd] Waiting for the new etcd member to join the cluster. This can take up to 40s
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[mark-control-plane] Marking the node k8s-m2 as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node k8s-m2 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]

This node has joined the cluster and a new control plane instance was created:

* Certificate signing request was sent to apiserver and approval was received.
* The Kubelet was informed of the new secure connection details.
* Control plane (master) label and taint were applied to the new node.
* The Kubernetes control plane instances scaled up.
* A new etcd member was added to the local/stacked etcd cluster.

To start administering your cluster from this node, you need to run the following as a regular user:

	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config

Run 'kubectl get nodes' to see this node join the cluster.
```

* Check Node status By Run `kubectl get node`
```bash
[root@k8s-m1 ~]# kubectl get node
NAME     STATUS   ROLES    AGE     VERSION
k8s-m1   Ready    master   43h     v1.15.3
k8s-m2   Ready    master   2m39s   v1.15.3
```

* Running same command on k8s-m3 node
```bash
kubeadm join haproxy1:8443 --token dvj9of.s9wfiznwv53007ly --discovery-token-ca-cert-hash sha256:0329f41276e2336e32053d284f9dbcaca8fe1b12b37b63c9146851982fff2a52 --control-plane --certificate-key 1aa5c6bdf5691eb4e92ed7d87d97f55b0c8f2614e2bda9b9644f62bf1b4f6548
```

* Waiting for a moment
```bash
[root@k8s-m1 ~]# kubectl get node
NAME     STATUS   ROLES    AGE     VERSION
k8s-m1   Ready    master   43h     v1.15.3
k8s-m2   Ready    master   7m57s   v1.15.3
k8s-m3   Ready    master   15m     v1.15.3
```

#### Token expire join method (Workers)

* Install Setup workers
```bash
ansible-playbook -i k8s-hosts.ini update_hosts.yml
ansible-playbook -i k8s-hosts.ini 02-install_docker.yml
ansible-playbook -i k8s-hosts.ini 03-install_kubelet.yml
```

* Join Workers Node
```bash
kubeadm join haproxy1:8443 --token dvj9of.s9wfiznwv53007ly --discovery-token-ca-cert-hash sha256:0329f41276e2336e32053d284f9dbcaca8fe1b12b37b63c9146851982fff2a52 
```
Output:
```bash
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
	[WARNING SystemVerification]: this Docker version is not on the list of validated versions: 19.03.0. Latest validated version: 18.09
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.15" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

sudo kubeadm join 192.168.0.200:6443 --token 9vr73a.a8uxyaju799qwdjv --discovery-token-ca-cert-hash sha256:7c2e69131a36ae2a042a339b33381c6d0d43887e2de83720eff5359e26aec866

* Check on Master Or kubectl
```bash
[root@k8s-m1 ~]# kubectl get node
NAME     STATUS   ROLES    AGE     VERSION
k8s-m1   Ready    master   46h     v1.15.3
k8s-m2   Ready    master   3h4m    v1.15.3
k8s-m3   Ready    master   3h12m   v1.15.3
k8s-n1   Ready    <none>   2m53s   v1.15.3
```

### TIPS

* Add roles to nodes in Kubernetes by `label`
```bash
[root@k8s-m1 ~]# kubectl label node k8s-n1 node-role.kubernetes.io/worker=
node/k8s-n1 labeled
[root@k8s-m1 ~]# kubectl get node
NAME     STATUS   ROLES    AGE         VERSION
k8s-m1   Ready    master   46h         v1.15.3
k8s-m2   Ready    master   175m        v1.15.3
k8s-m3   Ready    master   3h3m        v1.15.3
k8s-n1   Ready    worker   <invalid>   v1.15.3
```

* Readd a delete node
On deleted node operations:
```bash
kubeadm reset
kubeadm join haproxy1:8443 --token dvj9of.s9wfiznwv53007ly --discovery-token-ca-cert-hash sha256:0329f41276e2336e32053d284f9dbcaca8fe1b12b37b63c9146851982fff2a52
```

* Remove node completely 
On Master Node:
```bash
kubectl delete node node_name
```

On Deleted Worker node:
```bash
kubectl reset
ip link delete cni0
ip link delete flannel.1
```


### Troubleshooting

1. REF: [troubleshooting-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)

2. 错误1
```bash
Sep  2 04:29:03 k8s-n1 dockerd: time="2019-09-02T04:29:03.820213013-04:00" level=info msg="ignoring event" module=libcontainerd namespace=moby topic=/tasks/delete type="*events.TaskDelete"
Sep  2 04:29:03 k8s-n1 kubelet: E0902 04:29:03.873445   23150 remote_runtime.go:105] RunPodSandbox from runtime service failed: rpc error: code = Unknown desc = failed to set up sandbox container "4e62c8449d189abee29dd1201320c04f72c150a5a7eb8d3c2d6356d8c6fb7605" network for pod "nginx-test-79cd7499bf-zkgs6": NetworkPlugin cni failed to set up pod "nginx-test-79cd7499bf-zkgs6_default" network: open /run/flannel/subnet.env: no such file or directory
Sep  2 04:29:03 k8s-n1 kubelet: E0902 04:29:03.873549   23150 kuberuntime_sandbox.go:68] CreatePodSandbox for pod "nginx-test-79cd7499bf-zkgs6_default(4a26ea81-4803-48e3-8567-e2e2ffd957b6)" failed: rpc error: code = Unknown desc = failed to set up sandbox container "4e62c8449d189abee29dd1201320c04f72c150a5a7eb8d3c2d6356d8c6fb7605" network for pod "nginx-test-79cd7499bf-zkgs6": NetworkPlugin cni failed to set up pod "nginx-test-79cd7499bf-zkgs6_default" network: open /run/flannel/subnet.env: no such file or directory
Sep  2 04:29:03 k8s-n1 kubelet: E0902 04:29:03.873605   23150 kuberuntime_manager.go:692] createPodSandbox for pod "nginx-test-79cd7499bf-zkgs6_default(4a26ea81-4803-48e3-8567-e2e2ffd957b6)" failed: rpc error: code = Unknown desc = failed to set up sandbox container "4e62c8449d189abee29dd1201320c04f72c150a5a7eb8d3c2d6356d8c6fb7605" network for pod "nginx-test-79cd7499bf-zkgs6": NetworkPlugin cni failed to set up pod "nginx-test-79cd7499bf-zkgs6_default" network: open /run/flannel/subnet.env: no such file or directory
Sep  2 04:29:03 k8s-n1 kubelet: E0902 04:29:03.873731   23150 pod_workers.go:190] Error syncing pod 4a26ea81-4803-48e3-8567-e2e2ffd957b6 ("nginx-test-79cd7499bf-zkgs6_default(4a26ea81-4803-48e3-8567-e2e2ffd957b6)"), skipping: failed to "CreatePodSandbox" for "nginx-test-79cd7499bf-zkgs6_default(4a26ea81-4803-48e3-8567-e2e2ffd957b6)" with CreatePodSandboxError: "CreatePodSandbox for pod \"nginx-test-79cd7499bf-zkgs6_default(4a26ea81-4803-48e3-8567-e2e2ffd957b6)\" failed: rpc error: code = Unknown desc = failed to set up sandbox container \"4e62c8449d189abee29dd1201320c04f72c150a5a7eb8d3c2d6356d8c6fb7605\" network for pod \"nginx-test-79cd7499bf-zkgs6\": NetworkPlugin cni failed to set up pod \"nginx-test-79cd7499bf-zkgs6_default\" network: open /run/flannel/subnet.env: no such file or directory"
```

检查worker 节点上的kube-proxy状态.发现时镜像没有拉到。
``bash
kube-flannel-ds-amd64-cpr9m      0/1     CrashLoopBackOff   3          16m     172.16.193.231   k8s-n1   <none>           <none>
kube-proxy-ddczx                 0/1     ErrImagePull       0          16m     172.16.193.231   k8s-n1   <none>           <none>
```

解决方式：
先把kube-proxy 以及kube-flannel的镜像拉到node节点上，等两个pod都正常running之后。创建的测试pod就可以使用了。
