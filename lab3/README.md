# How to use RBAC to restrict user permissions

> First, let's talk about cluster authentication. When a request is received by the API server,it goes through the list of authenication plugins, so they can each examine the request and try to determine who's sending the request. The First plugin that can extract that information from the request returns the username, user ID, and the groups the client belongs to back to the API server core. The API server stops invoking the remaining authenication plugins and continues onto the authorization phase. -- Ref: Kubernetes In Action

Kubernetes supports the following authentication methods:

* Client certificate
* HTTP Token
* Basic HTTP authentication
* Others

In kubernetes, There are two kinds of clients to connect the API Server:
* Actual humans(User) --> Role & ClusterRoles Resource
* Pods --> ServiceAccounts Resource

Kubernetes also includes other authorization plugins:

* ABAC(Attribute-based access control) plugin
* RBAC (Role-Based Access Control)
* WebHook
* Custom plugin

### Introducing RBAC

 who --> User / SA 
       | |
       | |
        V
 RoleBindings / ClusterRoleBindings
       ^^
       ||
       ||
 what to do --> Cluster resource and Verb ( Roles / ClusterRoles )

### Create kubeconfig for new users

* Create User kubeconfig
```bash
[root@k8s-m1 ~]# kubeadm alpha kubeconfig user --client-name=aliasmee --apiserver-advertise-address=172.16.193.245 --apiserver-bind-port=8443
```

Save the output of the above command as a kubeconfig file. Path: (/home/.kube/config), If you already have other cluster configurations locally, what you need to do now is to merge the new kubeconfig together.

* Merge kubeconfig to config
```bash
$ export KUBECONFIG=/Users/`whoami`/.kube/config:/path/to/file/new-k8s-kubeconfig.yml
```

Merge to overrides config
```bash
$ kubectl config view --flatten > /Users/`whoami`/.kube/config
```

Check & verify
```bash
$ kubectl config get-contexts
CURRENT   NAME                                                 CLUSTER             AUTHINFO           NAMESPACE
*         aliasmee@kubernetes                                  kubernetes-office   aliasmee           
          kubernetes-admin-cb79817c894e24ead82daad2b606607a9   kubernetes          kubernetes-admin   
```

```bash
$ kubectl get po 
No resources found.
Error from server (Forbidden): pods is forbidden: User "aliasmee" cannot list resource "pods" in API group "" in the namespace "default"
```

Now, As you can see, user `aliasmee` are no permisions. 

### Role & RoleBindings

> A `Role` can only be used to grant access to resources within a single namespace.  

* Now, We will create a role to view the default namespace permissions.

```bash
# kubectl create -f - <<EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: default
  name: manager-default-role
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["deployments", "replicasets", "pods","pods/log", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] 

EOF
```

* Bind the role to user `aliasmee`
```bash
# kubectl create -f - <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: manager-default-binding
  namespace: default
subjects:
- kind: User
  name: aliasmee
  apiGroup: ""
roleRef:
  kind: Role
  name: manager-default-role
  apiGroup: ""
EOF
```

* Check & Verify kubectl
```bash
$ kubectl get po
NAME                          READY     STATUS    RESTARTS   AGE
nginx-test-79cd7499bf-6cswd   1/1       Running   0          20h
```

```bash
$ kubectl get pod -n metallb-system
No resources found.
Error from server (Forbidden): pods is forbidden: User "aliasmee" cannot list resource "pods" in API group "" in the namespace "metallb-system"
```
What's the matter ?


### ClusterRole & ClusterRoleBindings

* Create clusterrole
```bash
# kubectl create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: aliasmee
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
  - list
  - watch
  - delete
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list

EOF
```

* Create clusterrolebinds
```bash
# kubectl create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: aliasmee
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: aliasmee
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: aliasmee
  apiGroup: ""

EOF
```

* Check & Verify
```bah
$ kubectl get po -nmetallb-system
NAME                        READY     STATUS    RESTARTS   AGE
controller-55d74449-vd6f6   1/1       Running   0          20h
speaker-5c6dk               1/1       Running   0          20h
speaker-g74q6               1/1       Running   0          20h
speaker-hrcsw               1/1       Running   0          20h
speaker-ndx67               1/1       Running   0          20h
```

### RBAC Practice

> Always run under least-privileged user accounts and assign only needed permissions.

```bash
# kubectl create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cs:ns:readonly
rules:
- apiGroups:
  - ""
  resources:
  - namespaces
  - pods
  - pods/attach
  - pods/exec
  - pods/portforward
  - pods/proxy
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - configmaps
  - endpoints
  - persistentvolumeclaims
  - replicationcontrollers
  - replicationcontrollers/scale
  - secrets
  - serviceaccounts
  - services
  - services/proxy
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - events
  - replicationcontrollers/status
  - pods/log
  - pods/status
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - daemonsets
  - deployments
  - deployments/rollback
  - deployments/scale
  - replicasets
  - replicasets/scale
  - statefulsets
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - autoscaling
  resources:
  - horizontalpodautoscalers
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - batch
  resources:
  - cronjobs
  - jobs
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - extensions
  resources:
  - daemonsets
  - deployments
  - deployments/rollback
  - deployments/scale
  - ingresses
  - replicasets
  - replicasets/scale
  - replicationcontrollers/scale
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - servicecatalog.k8s.io
  resources:
  - clusterserviceclasses
  - clusterserviceplans
  - clusterservicebrokers
  - serviceinstances
  - servicebindings
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - policy
  resources:
  - poddisruptionbudgets
  verbs:
  - get
  - list
```
OR
```bash
kubectl apply -f https://raw.githubusercontent.com/aliasmee/kube-ops/master/lab3/readonly-cluster-roles.yml
```

If you want to create a user and have the above permissions, create a clusterrolebindings binding to a user.

