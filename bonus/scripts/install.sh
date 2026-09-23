#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

# Helm installer script + GitLab's official Helm chart repo (for its dependency script)
HELM_INSTALLER="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4"
GITLAB_SCRIPT_FOR_DEPENDENCIES="https://gitlab.com/gitlab-org/charts/gitlab.git"

# Install Helm (needed to deploy GitLab's Helm chart)
echo -e "${BLUE}\nInstalling Helm ...${NC}"
sleep 1
curl -fsSL "$HELM_INSTALLER" | bash

# System package required by GitLab's dependency setup script
sudo apt install -y util-linux-extra

# Clone GitLab's chart repo, only for its dependency script (not our own project)
if [ -d gitlab ]; then
  echo -e "${GREEN}GitLab directory already exists, cloning ignored.${NC}"
else
  git clone "$GITLAB_SCRIPT_FOR_DEPENDENCIES"
fi
chmod 744 gitlab/scripts/dev_dependencies.sh
# Prepare the machine (packages, system settings) before installing GitLab
NAMESPACE=gitlab bash gitlab/scripts/dev_dependencies.sh setup