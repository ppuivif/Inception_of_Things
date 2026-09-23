#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

BONUS_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Gateway API CRDs that can conflict with the GitLab Helm chart install
GATEWAY_CRDS=(
  backendtlspolicies.gateway.networking.k8s.io
  gatewayclasses.gateway.networking.k8s.io
  gateways.gateway.networking.k8s.io
  grpcroutes.gateway.networking.k8s.io
  httproutes.gateway.networking.k8s.io
  listenersets.gateway.networking.k8s.io
  referencegrants.gateway.networking.k8s.io
  tcproutes.gateway.networking.k8s.io
  tlsroutes.gateway.networking.k8s.io
  udproutes.gateway.networking.k8s.io
  xbackends.gateway.networking.x-k8s.io
  xbackendtrafficpolicies.gateway.networking.x-k8s.io
  xmeshes.gateway.networking.x-k8s.io
)

echo -e "${BLUE}\nCleaning up pre-existing Gateway API CRDs to avoid Helm conflicts ...${NC}"
for crd in "${GATEWAY_CRDS[@]}"; do
  kubectl delete crd "$crd" --ignore-not-found=true
done

# Local hostname used to reach GitLab from the browser
HOST_ENTRY="127.0.0.1 gitlab.k3d.gitlab.com"
HOSTS_FILE="/etc/hosts"
GITLAB_NAMESPACE="gitlab"

# Add the GitLab hostname to /etc/hosts if it's not already there
if grep -Fq -- "$HOST_ENTRY" "$HOSTS_FILE"; then
  echo -e "${GREEN}$HOSTS_FILE already contains the GitLab host.${NC}"
else
  echo -e "${BLUE}Adding the GitLab host to $HOSTS_FILE ...${NC}"
  printf '%s\n' "$HOST_ENTRY" | sudo tee -a "$HOSTS_FILE"
fi

# Create the dedicated namespace for GitLab if it doesn't exist yet
if kubectl get namespace "$GITLAB_NAMESPACE" >/dev/null 2>&1; then
    echo -e "${GREEN}\nNamespace $GITLAB_NAMESPACE already exists.${NC}"
else
  echo -e "${BLUE}\nCreation of $GITLAB_NAMESPACE namespace ...${NC}"
  kubectl create namespace "$GITLAB_NAMESPACE"
fi

# Install GitLab itself via its Helm chart, using lightweight external services
echo -e "${BLUE}\nInstalling GitLab via Helm in namespace $GITLAB_NAMESPACE ...${NC}"
helm repo add gitlab https://charts.gitlab.io/
helm repo update

helm upgrade --install gitlab gitlab/gitlab \
  --namespace "$GITLAB_NAMESPACE" \
  --values "$BONUS_DIR/values-minikube-minimum.yaml" \
  --values "$BONUS_DIR/gitlab/.values/dev-external.values.yaml" \
  --set global.hosts.domain=k3d.gitlab.com \
  --set global.hosts.externalIP=0.0.0.0 \
  --set global.hosts.https=false \
  --set global.ingress.configureCertmanager=false \
  --set global.gatewayApi.enabled=false \
  --set global.gatewayApi.configureCertmanager=false \
  --timeout 600s

echo -e "${BLUE}\nWaiting for GitLab podsready ...${NC}"
kubectl wait --for=condition=ready --timeout=1200s pod -l app=webservice --namespace "$GITLAB_NAMESPACE"

# Save the auto-generated root password to a local file for later login
kubectl get secret gitlab-gitlab-initial-root-password \
  --namespace "$GITLAB_NAMESPACE" \
  --output=jsonpath="{.data.password}" | base64 -d > gitlab_password.txt
sudo -v

# Expose GitLab locally on port 80 (needs sudo, privileged port)
echo -e "${BLUE}\nPort-forwarding to GitLab ...${NC}"
if nc -z localhost 80; then
	if lsof -iTCP:80 | grep -q 'kubectl'; then
			echo -e "${GREEN}\nGitLab port-forward is already running.${NC}"
	else
		echo -e "${RED}\nPort 80 is already used by another process.${NC}"
		exit 1
	fi
else
  sudo KUBECONFIG="$HOME/.kube/config" kubectl port-forward svc/gitlab-webservice-default 80:8181 \
  --namespace "$GITLAB_NAMESPACE" 2>&1 >/dev/null &
fi