#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

HELM_INSTALLER="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4"
GITLAB_SCRIPT_FOR_DEPENDENCIES="https://gitlab.com/gitlab-org/charts/gitlab.git"

echo -e "${BLUE}\nInstalling Helm ...${NC}"
sleep 1
curl -fsSL "$HELM_INSTALLER" | bash

sudo apt install -y util-linux-extra

if [ -d gitlab ]; then
  echo -e "${GREEN}GitLab directory already exists, cloning ignored.${NC}"
else
  git clone "$GITLAB_SCRIPT_FOR_DEPENDENCIES"
fi
chmod 744 gitlab/scripts/dev_dependencies.sh
NAMESPACE=gitlab bash gitlab/scripts/dev_dependencies.sh setup