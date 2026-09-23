#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

# Push any local change to the GitLab repo (triggers Argo CD's auto-sync)
pushd gitlab_repo >/dev/null
git add .
git commit -m "update the repo" || echo -e "${GREEN}No changes to push.${NC}"
git push
popd >/dev/null

# Force a manual sync in case auto-sync didn't trigger
argocd app sync wil-playground2

# Restart the port-forward, in case the pod/service changed after the sync
echo -e "${BLUE}\nInit new connection to app ...${NC}"
pkill -f "port-forward.*8889" || true
sleep 2
kubectl port-forward svc/wil-playground2 -n dev 8889:8888 &
sleep 2