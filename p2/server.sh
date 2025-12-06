#!/bin/bash
set -eux

curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

sudo apt update -y
sudo apt install -y net-tools

/usr/local/bin/kubectl create configmap app1-html \
  --from-file=index.html=/pods-cfg/app1/index.html \
  --dry-run=client -o yaml | /usr/local/bin/kubectl apply -f -
/usr/local/bin/kubectl apply -f /pods-cfg/app1/app1.yaml


/usr/local/bin/kubectl create configmap app2-html \
  --from-file=index.html=/pods-cfg/app2/index.html \
  --dry-run=client -o yaml | /usr/local/bin/kubectl apply -f -
/usr/local/bin/kubectl apply -f /pods-cfg/app2/app2.yaml


/usr/local/bin/kubectl create configmap app3-html \
  --from-file=index.html=/pods-cfg/app3/index.html \
  --dry-run=client -o yaml | /usr/local/bin/kubectl apply -f -
/usr/local/bin/kubectl apply -f /pods-cfg/app3/app3.yaml