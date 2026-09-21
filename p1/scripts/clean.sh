#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "${SCRIPT_DIR}/config.sh"

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error : do not run this script with sudo.${NC}"
    exit 1
fi

cd "$PROJECT_DIR" || exit 1

echo "=== P1 cleaning ==="
vagrant destroy -f

rm -f token

echo
echo "=== Checking for remaining VMs ==="
if vagrant status | grep -qE 'running|poweroff|saved|aborted'; then
    echo -e "${RED}At least one VM still exists.${NC}"
else
    echo -e "${GREEN}No VM in association with the project exists anymore.${NC}"
fi

rm -rf .vagrant
