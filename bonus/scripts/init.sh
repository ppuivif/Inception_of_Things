#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

# GitLab project name/namespace, and its root password (used for git auth)
GITLAB_PROJECT="${GITLAB_PROJECT:-root/new_test}"
GITLAB_NAMESPACE="gitlab"
GITLAB_PASSWORD="$(sudo KUBECONFIG="$HOME/.kube/config" kubectl get secret gitlab-gitlab-initial-root-password \
  --namespace "$GITLAB_NAMESPACE" \
  --output=jsonpath="{.data.password}" | base64 -d)"
NETRC_FILE="$HOME/.netrc"

# Store GitLab credentials so git can push without asking for a password
printf 'machine gitlab.k3d.gitlab.com\nlogin root\npassword %s\n' \
  "$GITLAB_PASSWORD" > "$NETRC_FILE"
sudo chmod 600 "$NETRC_FILE"

# Remove any stale local clone, then clone the (empty) GitLab project
if [ -d gitlab_repo ]; then
  rm -rf gitlab_repo
fi

git clone "http://gitlab.k3d.gitlab.com/$GITLAB_PROJECT.git" gitlab_repo

# Copy p3's manifests into the GitLab repo and rename the app to avoid conflicts
rm -rf gitlab_repo/confs
cp -r "$SCRIPT_DIR/../../p3/confs" gitlab_repo/confs
rm -rf "$SCRIPT_DIR/../gitlab_repo/confs/.git/"
sed -i 's/wil-playground/wil-playground2/g' gitlab_repo/confs/*.yaml

# Push the manifests to GitLab
pushd gitlab_repo >/dev/null
git config user.email "root@root.com"
git config user.name "root"
git add .
git commit -m "update the repo" || echo "no changes to push"
git push
popd >/dev/null

# Create the Argo CD app watching this GitLab repo instead of GitHub
argocd app create wil-playground2 \
  --repo "http://gitlab-webservice-default.gitlab.svc:8181/$GITLAB_PROJECT.git" \
  --path confs \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --project default \
  --sync-policy automated \
  --upsert

# Wait until the app's deployment is up and running
echo -e "${BLUE}Wait for app deployment ...${NC}"
while ! kubectl -n dev get deployment wil-playground2 &> /dev/null; do
  sleep 3
done

kubectl wait --for=condition=available --timeout=120s deployment/wil-playground2 -n dev

# Expose the app locally on port 8889
echo -e "${BLUE}\nPort-forwarding to app ...${NC}"
if nc -z localhost 8889; then
	if lsof -iTCP:8889 | grep -q 'kubectl'; then
			echo -e "${GREEN}\nApp port-forward is already running.${NC}"
	else
		echo -e "${RED}\nPort 8889 is already used by another process.${NC}"
		exit 1
	fi
else
  kubectl port-forward svc/wil-playground2 8889:8888 \
  --namespace dev 2>&1 >/dev/null &
fi