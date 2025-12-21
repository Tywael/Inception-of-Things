#!/usr/bin/env bash
set -euo pipefail

bash ./install.sh

echo "[+] Starting Argo CD port-forward on https://localhost:8080"
kubectl -n argocd port-forward svc/argocd-server 8080:443