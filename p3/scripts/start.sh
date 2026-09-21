#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

chmod +x "$0"

# Check if user is member of Docker group and add if necessary
if groups | grep -q '\bdocker\b'; then
	echo -e "${GREEN}\nUser already belongs to Docker group ${NC}"
else
	echo -e "${BLUE}\nAdding $USER to the docker group ...${NC}"
	sudo usermod -aG docker "$USER"
	echo -e "${BLUE}\nRe-executing script with docker group active ...${NC}"
	exec sudo -u "$USER" -g docker "$0" "$@"
fi

# Check if cluster iot exists, otherwise create it 
if k3d cluster list | grep -q '^iot[[:space:]]'; then
	echo -e "${GREEN}\nCluster 'iot' already exists.${NC}"
else
	echo -e "${BLUE}\nCreating the cluster 'iot' ..."
	k3d cluster create iot
fi

# Check if namespaces exist, otherwise create them
if kubectl get ns | grep -q '^argocd[[:space:]]'; then
  echo -e "${GREEN}\nNamespace 'argocd' already exists.${NC}"
else
	echo -e "${BLUE}\nAdding the namespace 'argocd' ...${NC}"
  kubectl create namespace argocd
fi

if kubectl get ns | grep -q 'dev[[:space:]]'; then
  echo -e "${GREEN}\nNamespace 'dev' already exists.${NC}"
else
	echo -e "${BLUE}\nAdding the namespace 'dev' ...${NC}"
  kubectl create namespace dev
fi

echo -e "${BLUE}\nInstalling Argo CD in its namespace ...${NC}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${BLUE}\nWaiting for argocd-server availability ...${NC}\n"
kubectl wait --for=condition=available --timeout=180s deployment.apps/argocd-server -n argocd

while ! kubectl -n argocd get secret argocd-initial-admin-secret &> /dev/null; do
  echo -e "${BLUE}\nWaiting for argocd initial admin secret ...${NC}"
  sleep 3
done

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo -e "${BLUE}\nPort-forwarding to ArgoCD's API ...${NC}"
if nc -z localhost 8080; then
  if lsof -i :8080 | grep -q 'kubectl'; then
    echo -e "${GREEN}\nArgo CD port-forward is already running.${NC}"
  else
    echo -e "${RED}\nPort 8080 is already used by another process.${NC}"
    exit 1
  fi
else
  kubectl port-forward svc/argocd-server -n argocd 8080:443 &
  while ! nc -z localhost 8080; do
    sleep 1
  done
fi

echo -e "\nLogging into Argo CD\n"
argocd login localhost:8080 --username admin --password "$ARGOCD_PASS" --insecure

sleep 1
argocd repo add https://github.com/Nofy261/iot_nolecler
sleep 1
argocd app create wil-playground \
  --repo https://github.com/Nofy261/iot_nolecler \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --project default \
  --sync-policy automated

echo -e "\nWaiting for app deployment...\n"
while ! kubectl -n dev get deployment wil-playground &> /dev/null; do
  sleep 3
done

kubectl wait --for=condition=available --timeout=120s deployment/wil-playground -n dev

echo -e "${BLUE}\nPort-forwarding to the app ...${NC}"
if nc -z localhost 8888; then
	if lsof -i :8888 | grep -q 'kubectl'; then
			echo -e "${GREEN}\nApp port-forward is already running.${NC}"
	else
		echo -e "${RED}\nPort 8888 is already used by another process.${NC}"
		exit 1
	fi
else kubectl port-forward svc/wil-playground -n dev 8888:8888 2>&1 >/dev/null &
fi