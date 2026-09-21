#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

# Get the network interface associated to IP
IFACE=$(ip -o addr show | awk '$4 ~ /^192.168.56./ {print $2}' | head -1)

# Install k3s server
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=$IFACE --write-kubeconfig-mode=644" sh -s -

echo -e "${BLUE}\nWaiting for K3s API to be ready ...${NC}"
until kubectl get nodes >/dev/null 2>&1; do
    sleep 2
done

kubectl apply -f /vagrant/confs/

echo -e "${GREEN}\nDone${NC}"