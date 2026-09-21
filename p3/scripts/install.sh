#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

# Tools install
echo -e "${BLUE}\nInstalling tools ...${NC}"
sudo apt-get update
sudo apt-get install ca-certificates curl netcat-openbsd lsof -y
sudo install -m 0755 -d /etc/apt/keyrings

# Get CPU architecture
ARCH=$(dpkg --print-architecture)

# Download GPG Docker key
echo -e "${BLUE}\nDownloading Docker GPG key ...${NC}"
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repo 
echo -e "${BLUE}\nConfigure the Docker repository in APT ...${NC}"
echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y

# Docker installation
echo -e "${BLUE}\nInstalling Docker ...${NC}"
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# K3d installation
echo -e "${BLUE}\nInstalling K3d ...${NC}"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# kubectl installation
echo -e "${BLUE}\nInstalling kubectl ...${NC}"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Argo CD CLI installation
echo -e "${BLUE}\nInstalling Argo CD CLI ...${NC}"
VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-${ARCH}"
chmod +x argocd
sudo mv argocd /usr/local/bin/
