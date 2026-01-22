#!/usr/bin/env bash
set -euxo pipefail  # Enable strict error handling

# Utility functions for logging and error handling
log(){ echo -e "\033[1;32m[+] $*\033[0m"; }
warn(){ echo -e "\033[1;33m[!] $*\033[0m"; }
die(){ echo -e "\033[1;31m[x] $*\033[0m" >&2; exit 1; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "This script must be run as root (sudo ./install.sh)"

HOST="127.0.0.1 localhost"
if ! grep -q "localhost" /etc/hosts; then
    echo "$HOST" >> /etc/hosts
fi

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
if ! k3d cluster list | grep -q "^iot-bonus"; then
    k3d cluster create iot-bonus \
        -p "80:80@server:0" \
        -p "443:443@server:0" \
        -p "8888:8888@server:0" \
        --agents 1 \
        --k3s-arg "--disable=traefik@server:0"
    log "k3d cluster iot-bonus created."
else
    log "k3d cluster iot-bonus already exists, skipping creation."
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
kubectl apply -f ./confs/deploy.yaml
log "Applications deployed successfully."

kubectl -n argocd get applications
kubectl -n dev get svc,pods
log "GitOps setup done. Argo CD will now sync from GitHub."

# ========== GitLab Installation ==========
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

# install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# install ingress-nginx
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
helm repo list | awk '{print $1}' | grep -qx ingress-nginx || helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClass=nginx \
  --set controller.service.type=LoadBalancer

kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s
log "Ingress Nginx deployed and ready."

# install gitlab
helm repo list | awk '{print $1}' | grep -qx gitlab || helm repo add gitlab https://charts.gitlab.io
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f ./confs/gitlab-values-k3d-min.yaml

# Wait for GitLab pods to be ready
log "Waiting for GitLab pods to start (this may take 5-10 minutes)..."
kubectl -n gitlab rollout status deployment/gitlab-webservice-default --timeout=600s || warn "GitLab webservice taking longer, continuing..."
sleep 30

kubectl -n gitlab get pods
log "GitLab installation completed."

# ========== Configure DNS for GitLab ==========
log "Configuring CoreDNS for gitlab.localhost..."
GITLAB_IP=$(kubectl -n gitlab get svc gitlab-webservice-default -o jsonpath='{.spec.clusterIP}')

# Add hosts entry to CoreDNS
kubectl -n kube-system patch configmap coredns --type strategic --patch "{
  \"data\": {
    \"Corefile\": \".:53 {\\n    errors\\n    health\\n    ready\\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\\n       pods insecure\\n       fallthrough in-addr.arpa ip6.arpa\\n       ttl 30\\n    }\\n    hosts {\\n       $GITLAB_IP gitlab.localhost\\n       fallthrough\\n    }\\n    prometheus :9153\\n    forward . /etc/resolv.conf\\n    cache 30\\n    loop\\n    reload\\n    loadbalance\\n}\\n\"
  }
}" || true

kubectl -n kube-system rollout restart deployment/coredns
sleep 15

log "CoreDNS configured for gitlab.localhost ($GITLAB_IP)"