#!bin/bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl get pods -n kubernetes-dashboard
kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa
echo "apiVersion: v1
kind: Secret
metadata:
  name: dashboard-admin-sa-token
  annotations:
    kubernetes.io/service-account.name: dashboard-admin-sa
type: kubernetes.io/service-account-token
" >secret.yaml
kubectl apply -f secret.yaml
kubectl get svc kubernetes-dashboard -n kubernetes-dashboard  -o yaml >dashboardsvc.yaml
sed -i 's/type: ClusterIP/type: NodePort/g' dashboardsvc.yaml
kubectl apply -f dashboardsvc.yaml
echo "Hay you can use below URL for your browsing fro your network , replaace the node IP with your any kds node IP"
kubectl describe svc kubernetes-dashboard -n kubernetes-dashboard |grep NodePort |grep TCP |awk '{print $NF}'|awk -F "/" '{print "https://nodeip:"$1}'
echo "You can use below token to connect your K8s Dashboard "
kubectl describe secret dashboard-admin-sa-token |grep token
