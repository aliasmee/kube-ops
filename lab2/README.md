# How to use LB on bare metal ?

### Install & Setup metallb

##### Install

```bash
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.1/manifests/metallb.yaml
```

#### Config layer 2
Create metallb config file:

```bash
$ kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 172.16.192.50-172.16.192.99
---
EOF
```

### Test and verify metallb correnct work

#### Create nginx deployment and LoadBalancer type Service

```bash
$ kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx-test
    run: nginx-test
  name: ng-test
  namespace: default
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  selector:
    run: nginx-test
  type: LoadBalancer

---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    run: nginx-test
  name: nginx-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      run: nginx-test
  template:
    metadata:
      labels:
        run: nginx-test
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx-test
---
EOF
```

#### Get LB IP

```bash
$ kubectl get svc,po -l run=nginx-test
NAME              TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                      AGE
service/ng-test   LoadBalancer   10.97.248.22   172.16.192.50   80:31043/TCP,443:31727/TCP   86s

NAME                              READY   STATUS    RESTARTS   AGE
pod/nginx-test-79cd7499bf-x65ph   1/1     Running   0          16m
```

#### Access Nginx servce index by curl client
```bash
$ curl 172.16.192.50
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
