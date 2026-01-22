#!/usr/bin/env bash
set -euo pipefail

bash ./scripts/install.sh

#kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d > gitlab_password.txt
# kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d && echo

echo "[+] Starting Argo CD port-forward on https://localhost:8080"
kubectl -n argocd port-forward svc/argocd-server 8080:443