kubectl apply -f serviceaccount.yaml
kubectl get svc kubernetes-dashboard -o yaml >dashboardsvc.yaml
sed -i 's/type: ClusterIP/type: NodePort/g' dashboardsvc.yaml
kubectl apply -f dashboardsvc.yaml
kubectl describe svc kubernetes-dashboard |grep NodePort |grep https |awk '{print $2"://nodeip:"$NF}'|awk -F "/TCP" '{print "Use below link for Browse your Dashboard   "   $1}'
EOF
  tags = {
    Name = "DebopsK8s"
  }
}
