# Ingress

### What?
Ingress 在Kubernetes集群中是所有资源类型的一种。负责将集群外部的HTTP/HTTPS请求转发到
集群内部实际运行的服务上(Pod，通过Service中所包含的Endpoint).

Ingress 类似我们在使用nginx主机时配置的虚拟主机。在Kubernetes中，我们通过定义ingress
资源，来配置我们的虚拟主机。

Kubernetes 抽象出这些规则，之后可以由不同的Ingress Controller来实现。当Ingress Controller
检测到Ingress 资源的变动。将会自动转换成该Controller实际的配置文件。比如Nginx，它就会动态
生成虚拟主机的配置。这点稍后我们可以进入到Nginx Controller Pod中一探究竟。

### Why?

如你知道的，把我们集群中的服务暴露外面有多种方式，如Service 类型中的NodePort、LoadBalancer.我们为什么还需要Ingress呢？

先说下NodePort，如果我们访问服务还需要添加端口，不太方便。当然你也可以在集群外面添加Nginx、haproxy反向代理，可之后的维护
会变得更繁琐复杂。还会增加一层消耗。

LoadBalancer类型可以给每个服务配置一个公网IP，但考虑IPV4的不足，且在云上是需要付费的。

而Ingress 只需要一个公网IP，即可以将所有服务通过Hosts、path开放到外部。这就需要搭配Ingress-controller来实现了。Ingress-controller
还可以做SSL的卸载功能. 

```bash

                           kubia.example.com      --------                  ------
                         / ---------------------> SVC kubia  ------------->  Pod
--------        --------/                         --------                  ------
 client  ---->   Ingress
--------        --------\                         --------
                         \ ---------------------> SVC hi                    ------
                           hi.example.com         --------   ------------->  Pod
                                                                            ------
```


### Choice one Ingress Controller

Ingress Controller 的种类变得越来越多。我记得刚开始时也只有Nginx、Traefik、Kong。现在的种类
已经发展十多种了。具体可转到这里查看[Kubernetes Ingress Controller List](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/#additional-controllers)

由于时间有限，只探索以下两种Ingress Controller哈：

* Nginx
* Traefik 

#### Nginx Ingress Controller

Nginx Web服务器已经在领域内占有Top1 的地位，所以我们就先从它开始。

Nginx controller 目前有两个主流版本，一个主要由Nginx官方维护[Nginx.Inc](https://github.com/nginxinc/kubernetes-ingress),
另外一个是Kubernetes 社区在维护的[Kubernetes ingress nginx](https://github.com/kubernetes/ingress-nginx/).
至于选哪个？可以看下对比[VS](https://github.com/nginxinc/kubernetes-ingress/blob/master/docs/nginx-ingress-controllers.md).

另外有些功能，在社区维护的版本中是支持的，到了Nginx官方维护的有只有付费Plus版本提供。本文介绍的是Kubernetes社区版本的ingress-nginx。


##### Ingress nginx 安装

先准备好必备条件:

在启用RBAC授权的集群中，需要预先创建一系列role，这样nginx-ingress 服务才能与Kubernetes API Server通信，用于监视Ingress资源；最后是创建
Nginx Server。

```bash
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
namespace/ingress-nginx configured
configmap/nginx-configuration created
configmap/tcp-services created
configmap/udp-services created
serviceaccount/nginx-ingress-serviceaccount created
clusterrole.rbac.authorization.k8s.io/nginx-ingress-clusterrole created
role.rbac.authorization.k8s.io/nginx-ingress-role created
rolebinding.rbac.authorization.k8s.io/nginx-ingress-role-nisa-binding created
clusterrolebinding.rbac.authorization.k8s.io/nginx-ingress-clusterrole-nisa-binding created
deployment.apps/nginx-ingress-controller created
```

创建4层Service，类型为LoadBalancer. 如果你的基础设施在云上，那么可以很方便的调用云供应商提供的LB。我这里使用的是自建的
LB方案项目，[Metallb](https://metallb.universe.tf/). 部署及使用，我会写在另外一篇文章中[How to build LoadBalancer on bare machine](https://aliasmee.github.io/)
使用该项目，我们就可以很方便的创建LB类型的Service。不用考虑NodePort的方式去暴露服务。

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/aws/service-l4.yaml
```

查看Ingress nginx controller 是否正常启动:
```bash
$ kubectl logs -f nginx-ingress-controller-79f6884cf6-ctjr5   
-------------------------------------------------------------------------------
NGINX Ingress controller
  Release:       0.25.1
  Build:         5179893a9
  Repository:    https://github.com/kubernetes/ingress-nginx
  N/A
-------------------------------------------------------------------------------

W0915 14:47:34.766212       1 flags.go:221] SSL certificate chain completion is disabled (--enable-ssl-chain-completion=false)
W0915 14:47:34.766429       1 client_config.go:541] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
I0915 14:47:34.767206       1 main.go:183] Creating API client for https://10.96.0.1:443
I0915 14:47:34.833686       1 main.go:227] Running in Kubernetes cluster version v1.15 (v1.15.3) - git (clean) commit 2d3c76f9091b6bec110a5e63777c332469e0cba2 - platform linux/amd64
I0915 14:47:35.480671       1 main.go:102] Created fake certificate with PemFileName: /etc/ingress-controller/ssl/default-fake-certificate.pem
I0915 14:47:35.639823       1 nginx.go:274] Starting NGINX Ingress controller
I0915 14:47:35.667329       1 event.go:258] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"ingress-nginx", Name:"udp-services", UID:"a687c305-ac5d-44cb-8a04-b8bee816ef87", APIVersion:"v1", ResourceVersion:"1680525", FieldPath:""}): type: 'Normal' reason: 'CREATE' ConfigMap ingress-nginx/udp-services
I0915 14:47:35.669208       1 event.go:258] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"ingress-nginx", Name:"nginx-configuration", UID:"03cc0b7e-1783-4e0a-8a77-8e98f2a9ba9b", APIVersion:"v1", ResourceVersion:"1680841", FieldPath:""}): type: 'Normal' reason: 'CREATE' ConfigMap ingress-nginx/nginx-configuration
I0915 14:47:35.683021       1 event.go:258] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"ingress-nginx", Name:"tcp-services", UID:"8feaab04-4678-449e-9e7b-dfb3045be578", APIVersion:"v1", ResourceVersion:"1680523", FieldPath:""}): type: 'Normal' reason: 'CREATE' ConfigMap ingress-nginx/tcp-services
E0915 14:47:36.670172       1 checker.go:41] healthcheck error: Get http+unix://nginx-status/healthz: dial unix /tmp/nginx-status-server.sock: connect: no such file or directory
I0915 14:47:36.841452       1 nginx.go:318] Starting NGINX process
I0915 14:47:36.841628       1 leaderelection.go:235] attempting to acquire leader lease  ingress-nginx/ingress-controller-leader-nginx...
I0915 14:47:36.843269       1 controller.go:133] Configuration changes detected, backend reload required.
I0915 14:47:36.915334       1 leaderelection.go:245] successfully acquired lease ingress-nginx/ingress-controller-leader-nginx
I0915 14:47:36.916140       1 status.go:86] new leader elected: nginx-ingress-controller-79f6884cf6-ctjr5
I0915 14:47:36.982947       1 controller.go:149] Backend successfully reloaded.
I0915 14:47:36.983031       1 controller.go:158] Initial sync, sleeping for 1 second.
```


##### 部署服务验证Ingress controller

部署一个简单的服务，这里的服务参考Kubernetes in action中第五章的示例：

创建一个rc，提供http服务:

```bash
 kubectl create ns ingress-ec
```

创建ReplicaSets

```bash
kubectl apply -f - <<EOF

apiVersion: v1
kind: ReplicationController
metadata:
  name: kubia
  namespace: ingress-ec
spec:
  replicas: 3
  selector:
    app: kubia
  template:
    metadata:
      labels:
        app: kubia
    spec:
      containers:
      - name: kubia
        image: luksa/kubia
        ports:
        - name: http
          containerPort: 8080
EOF
```

检查下pod是否启动，顺利的话，你会看到和下面类似的输出:

```bash
# kubectl get po -ningress-ec
NAME          READY   STATUS    RESTARTS   AGE
kubia-8hjl8   1/1     Running   0          19s
kubia-k59v5   1/1     Running   0          19s
kubia-xfv76   1/1     Running   0          19s
```

现在pod中的服务已经正常启动并运行了,但仅限于本身localhost可以访问，现在我们创建Service，通过`Label: app=kubia`来
绑定我们上一步创建的3个Pod.

```bash
kubectl apply -f - <<EOF

apiVersion: v1
kind: Service
metadata:
  name: kubia-svc
  namespace: ingress-ec
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: kubia

EOF
```

最后是创建Ingress 资源。定义访问Host为kubia.example.com，且访问Path为/（根）, 匹配上面的条件之后，将流量转发到
kubia-svc。这里也可以看出, Ingress 资源可以定义根据请求中不同的host 或path ，将流量转发到集群任意服务。

```bash
kubectl apply -f - <<EOF
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: kubia
  namespace: ingress-ec
spec:
  rules:
  - host: kubia.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: kubia-svc
          servicePort: 80
EOF
```

我们可以通过get查看刚创建的ingress资源，并且新版的API可以看到相应ingress-controlller Service服务的IP。

```bash
# kubectl get ing -ningress-ec
NAME    HOSTS               ADDRESS         PORTS   AGE
kubia   kubia.example.com   172.16.192.50   80      17m
```

上面ADDRESS那列，便是对应Nginx-controller Service 的IP，我们需要修改DNS记录，把kubia.example.com Host的A记录解析到该地址。
方便起见，我们直接修改本地/etc/hosts文件.

```bash
# sudo echo "172.16.192.50  kubia.example.com" >> /etc/hosts 
```

##### 本地验证下

```bash
# for i in `seq 3`; do curl kubia.example.com;done
You've hit kubia-8hjl8
You've hit kubia-k59v5
You've hit kubia-xfv76
```

如果你不想修改hosts，也可以在使用curl时，添加Host Header.

e.g.: `curl -H "Host: kubia.example.com" http://172.16.192.50`

### Install Traefik ingress

```bash
helm upgrade traefik azure-mirr/traefik --namespace kube-system --set rbac.enabled=true --set dashboard.enabled=true,dashboard.auth.basic.test='$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/' --set dashboard.domain=tk.example.com
```


### Q&A

1. 如果我的集群有多个ingress controller，如何根据需要选择不同的controller呢？

我们可以通过在Ingress资源中添加annotation: `kubernetes.io/ingress.class: nginx`. 因为每个Ingress-controller都有自己的标签。

如Nginx，我们可以在启动部署nginx-controller时，给它定义不同的class name。这样便与区分。

```bash
spec:
  template:
     spec:
       containers:
         - name: nginx-ingress-internal-controller
           args:
             - /nginx-ingress-controller
             - '--election-id=ingress-controller-leader-internal'
             - '--ingress-class=nginx-internal'
             - '--configmap=ingress/nginx-ingress-internal-controller'
```


