#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

pushd gitlab_repo >/dev/null
git add .
git commit -m "update the repo" || echo -e "${GREEN}No changes to push.${NC}"
git push
popd >/dev/null

argocd app sync wil-playground2

echo -e "${BLUE}\nInit new connection to app ...${NC}"
pkill -f "port-forward.*8889" || true
kubectl port-forward svc/wil-playground2 -n dev 8889:8888 &
sleep 2