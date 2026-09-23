#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

BONUS_DIR="$(dirname "$SCRIPT_DIR")"

GITLAB_DIR="${BONUS_DIR}/gitlab"
GITLAB_REPO_DIR="${BONUS_DIR}/gitlab_repo"
GITLAB_PASSWORD_FILE="${BONUS_DIR}/gitlab_password.txt"
EXTERNAL_CHARTS_DIR="${BONUS_DIR}/.external-charts"
NETRC_FILE="$HOME/.netrc"

HOST_ENTRY="127.0.0.1 gitlab.k3d.gitlab.com"
HOSTS_FILE="/etc/hosts"

echo -e "${BLUE}\nCleaning Bonus environment ...${NC}"

# Stop GitLab port-forward on port 80
echo -e "${BLUE}\nStopping GitLab port-forward ...${NC}"
if lsof -iTCP:80 -sTCP:LISTEN -n -P 2>/dev/null | grep -q kubectl; then
    sudo kill "$(sudo lsof -t -iTCP:80 -sTCP:LISTEN -n -P | head -n1)"
    echo -e "${GREEN}GitLab port-forward stopped.${NC}"
else
    echo -e "${GREEN}No GitLab port-forward found on port 80.${NC}"
fi

# Stop application port-forward on port 8889
echo -e "${BLUE}\nStopping application port-forward ...${NC}"
if lsof -iTCP:8889 -sTCP:LISTEN -n -P 2>/dev/null | grep -q kubectl; then
    kill "$(lsof -t -iTCP:8889 -sTCP:LISTEN -n -P | head -n1)"
    echo -e "${GREEN}Application port-forward stopped.${NC}"
else
    echo -e "${GREEN}No application port-forward found on port 8889.${NC}"
fi

# Remove local GitLab repository clone
echo -e "${BLUE}\nRemoving local GitLab repository ...${NC}"
if [ -d "$GITLAB_REPO_DIR" ]; then
    rm -rf "$GITLAB_REPO_DIR"
    echo -e "${GREEN}$GITLAB_REPO_DIR removed.${NC}"
else
    echo -e "${GREEN}No local GitLab repository found.${NC}"
fi

# Remove generated GitLab root password
echo -e "${BLUE}\nRemoving GitLab password file ...${NC}"
if [ -f "$GITLAB_PASSWORD_FILE" ]; then
    rm -f "$GITLAB_PASSWORD_FILE"
    echo -e "${GREEN}$GITLAB_PASSWORD_FILE removed.${NC}"
else
    echo -e "${GREEN}No GitLab password file found.${NC}"
fi

# Remove GitLab credentials
echo -e "${BLUE}\nRemoving Git credentials ...${NC}"
if [ -f "$NETRC_FILE" ]; then
    rm -f "$NETRC_FILE"
    echo -e "${GREEN}$NETRC_FILE removed.${NC}"
else
    echo -e "${GREEN}No .netrc file found.${NC}"
fi

# Remove GitLab chart repository clone
echo -e "${BLUE}\nRemoving GitLab chart repository ...${NC}"
if [ -d "$GITLAB_DIR" ]; then
    rm -rf "$GITLAB_DIR"
    echo -e "${GREEN}$GITLAB_DIR removed.${NC}"
else
    echo -e "${GREEN}No GitLab chart repository found.${NC}"
fi

# Remove cached external Helm chart dependencies
echo -e "${BLUE}\nRemoving external charts cache ...${NC}"
if [ -d "$EXTERNAL_CHARTS_DIR" ]; then
    rm -rf "$EXTERNAL_CHARTS_DIR"
    echo -e "${GREEN}$EXTERNAL_CHARTS_DIR removed.${NC}"
else
    echo -e "${GREEN}No external charts cache found.${NC}"
fi

# Remove GitLab hostname from /etc/hosts
echo -e "${BLUE}\nRemoving GitLab hostname from $HOSTS_FILE ...${NC}"
if grep -Fqx "$HOST_ENTRY" "$HOSTS_FILE"; then
    sudo sed -i "\|^${HOST_ENTRY}$|d" "$HOSTS_FILE"
    echo -e "${GREEN}GitLab hostname removed from $HOSTS_FILE.${NC}"
else
    echo -e "${GREEN}GitLab hostname not found in $HOSTS_FILE.${NC}"
fi

echo -e "${GREEN}\nBonus environment cleaned successfully.${NC}"