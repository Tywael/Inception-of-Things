#!/bin/bash
set -eux

SERVER_IP="192.168.56.110"

sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirrors.edge.kernel.org/ubuntu|g' /etc/apt/sources.list
apt-get clean
apt-get update -y -o Acquire::Retries=5 -o Acquire::http::No-Cache=True

apt-get install -y curl ca-certificates sudo

curl -sfL https://get.k3s.io -o /tmp/k3s_install.sh
chmod +x /tmp/k3s_install.sh

INSTALL_K3S_SKIP_START=true \
INSTALL_K3S_EXEC="--write-kubeconfig-mode=644 \
                  --node-ip=${SERVER_IP} \
                  --advertise-address=${SERVER_IP} \
                  --tls-san=${SERVER_IP}" \
  /tmp/k3s_install.sh

systemctl daemon-reload
systemctl enable k3s.service
systemctl start k3s.service

TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
echo "Waiting for K3s token..."
while [ ! -f "$TOKEN_FILE" ]; do sleep 2; done

cp "$TOKEN_FILE" /vagrant/token

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

echo "K3s server installed and running on ${SERVER_IP}:6443"