#!/bin/bash
set -eux

SERVER_IP="${1:?ERROR: Provide server IP as argument}"

sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirrors.edge.kernel.org/ubuntu|g' /etc/apt/sources.list
apt-get clean
apt-get update -y -o Acquire::Retries=5 -o Acquire::http::No-Cache=True

apt-get install -y curl ca-certificates sudo

TOKEN_FILE="/vagrant/token"
while [ ! -f "$TOKEN_FILE" ]; do sleep 2; done
TOKEN=$(cat "$TOKEN_FILE")

NODE_IP="192.168.56.111"

mkdir -p /etc/rancher/k3s
cat <<EOF >/etc/rancher/k3s/config.yaml
node-ip: ${NODE_IP}
EOF

curl -sfL https://get.k3s.io -o /tmp/k3s_install.sh
chmod +x /tmp/k3s_install.sh

K3S_URL="https://${SERVER_IP}:6443" \
K3S_TOKEN="${TOKEN}" \
  /tmp/k3s_install.sh

echo "Worker joined master at ${SERVER_IP}"

