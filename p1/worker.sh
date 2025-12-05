#!/bin/bash
set -eux

SERVER_IP="${1:?ERROR: Provide server IP as argument}"

sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirrors.edge.kernel.org/ubuntu|g' /etc/apt/sources.list
apt-get clean
apt-get update -y -o Acquire::Retries=5 -o Acquire::http::No-Cache=True

apt-get install -y curl ca-certificates sudo

TOKEN_FILE="/vagrant/token"
echo "Waiting for master token..."
while [ ! -f "$TOKEN_FILE" ]; do sleep 2; done
TOKEN=$(cat "$TOKEN_FILE")

curl -sfL https://get.k3s.io -o /tmp/k3s_install.sh
chmod +x /tmp/k3s_install.sh

INSTALL_K3S_SKIP_START=true \
K3S_URL="https://${SERVER_IP}:6443" \
K3S_TOKEN="${TOKEN}" \
  /tmp/k3s_install.sh

systemctl daemon-reload
systemctl enable k3s-agent.service
systemctl start k3s-agent.service

echo "Worker joined master at ${SERVER_IP}:6443"