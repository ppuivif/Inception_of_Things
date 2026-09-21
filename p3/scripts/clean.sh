#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

echo -e "${BLUE}\nCleaning IOT environment ...${NC}"

# Stop Argo CD port-forward
pkill -f "kubectl port-forward svc/argocd-server.*8080:443" 2>/dev/null || true

# Stop application port-forward
pkill -f "kubectl port-forward svc/wil-playground.*8888:8888" 2>/dev/null || true

# Delete Argo CD application
argocd app delete wil-playground --yes 2>/dev/null || true

k3d cluster stop iot

k3d cluster delete iot 

echo -e "${GREEN}\nCleaning completed.${NC}"