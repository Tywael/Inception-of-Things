# Inception of Things – P3 Cheatsheet

All commands are executed as **root**.

## 1. Kubectl context

```sh
kubectl config current-context
kubectl config get-contexts
```

 Verifies that the active context is `k3d-iot-p3`.


## 2. Cluster status

```sh
kubectl get nodes -o wide
```

 Verifies that the k3d cluster is running and the node is `Ready`.

```sh
kubectl get ns
```

 Verifies that the `argocd` and `dev` namespaces exist.


## 3. Argo CD status

```sh
kubectl -n argocd get pods
```

 Verifies that all Argo CD components are `Running`.

```sh
kubectl -n argocd get applications
```

 Verifies that the `iotp3-playground` application is `Synced / Healthy`.


## 4. Application resources (dev namespace)

```sh
kubectl -n dev get deploy,rs,pods,svc -o wide
```

 Verifies that the deployment, pod and service exist.

```sh
kubectl -n dev get deploy will-playground \
-o=jsonpath='{.spec.template.spec.containers[0].image}' && echo
```

 Displays the Docker image currently running (`v1` or `v2`).


## 5. Application test (port 8888)

```sh
curl http://localhost:8888/
```

 Verifies that the application responds (`v1` or `v2`).
```sh
kubectl -n argocd patch application iotp3-playground \
--type merge \
-p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```
Forces an immediate Argo CD resync
```sh
watch -n 1 'kubectl -n argocd get application iotp3-playground; \
echo; \
kubectl -n dev get deploy will-playground \
-o custom-columns=IMAGE:.spec.template.spec.containers[0].image'
```
Shows application sync/health status in real time

## 6. GitOps test (v1 → v2)

*(After modifying the image in the Git repository and committing/pushing the change)*

```sh
kubectl -n argocd get applications
```

 Verifies that Argo CD detected the Git change.

```sh
kubectl -n dev rollout status deploy/will-playground
```

 Waits for the Kubernetes rolling update to complete.

```sh
kubectl -n dev get deploy will-playground \
-o=jsonpath='{.spec.template.spec.containers[0].image}' && echo
```

 Confirms that the image was updated to `v2`.

```sh
curl http://localhost:8888/
```

 Verifies that the application now responds with `v2`.


## 7. Argo CD UI 

Default credentials are admin: and a randomly password generated inside the node.

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
-o jsonpath="{.data.password}" | base64 -d && echo
```

 Retrieves the Argo CD admin password.

 UI available at: https://localhost:8080

