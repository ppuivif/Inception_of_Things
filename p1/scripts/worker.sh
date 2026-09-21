#!/bin/bash

set -euo pipefail

# Get the network interface associated to IP
IFACE=$(ip -o addr show | awk '$4 ~ /^192.168.56./ {print $2}' | head -1)

# Get token
while [ ! -f /vagrant/token ]; do
  sleep 2
done

TOKEN=$(cat /vagrant/token)

# Install k3s worker
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=$IFACE" K3S_URL="https://192.168.56.110:6443" K3S_TOKEN="$TOKEN" sh -s -
