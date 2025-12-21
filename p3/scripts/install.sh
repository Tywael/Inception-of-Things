#!/usr/bin/env bash
set -euxo pipefail  # Enable strict error handling

# Utility functions for logging and error handling
log(){ echo -e "\033[1;32m[+] $*\033[0m"; }
warn(){ echo -e "\033[1;33m[!] $*\033[0m"; }
die(){ echo -e "\033[1;31m[x] $*\033[0m" >&2; exit 1; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "This script must be run as root (sudo ./install.sh)"

# ========== Docker setup ==========
# Prepare system for Docker installation
apt-get update -y 
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y

# Install Docker components
apt-get install -y docker-ce docker-ce-cli containerd.io
log "Docker installation completed."

systemctl enable --now docker.socket
systemctl enable --now docker.service
docker version
usermod -aG docker "${SUDO_USER:-$USER}"
log "Docker service is enabled and started."

# ========= K3d setup =========
# Install kubectl
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl
kubectl version --client

# Install k3d
curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
k3d version
log "k3d installation completed."

# Create k3d cluster
if ! k3d cluster list | grep -q "^iot-p3"; then
    k3d cluster create iot-p3 -p "8888:8888@loadbalancer"
    log "k3d cluster iot-p3 created."
else
    log "k3d cluster iot-p3 already exists, skipping creation."
fi

kubectl get nodes

# ========== Deploy Applications ==========
# Argo CD Installation
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd rollout status deployment/argocd-server --timeout=300s

kubectl get pods -n argocd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# gitops dev environment setup
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ../confs/deploy.yaml
log "Applications deployed successfully."

kubectl -n argocd get applications
kubectl -n dev get svc,pods
log "GitOps setup done. Argo CD will now sync from GitHub."
