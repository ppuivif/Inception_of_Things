#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "${SCRIPT_DIR}/config.sh"

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error : do not execute this script with sudo.${NC}"
    exit 1
fi

cd "$PROJECT_DIR" || exit 1

echo -e "${BLUE}\nP2 cleaning ...${NC}"

vagrant destroy -f

echo -e "${BLUE}\nCheck of existing VM ...${NC}"

if vagrant status | grep -q "not created"; then
    echo -e "${GREEN}No VM exists anymore.${NC}"
else
	echo -e "${RED}At least one VM still exists.${NC}"
fi

rm -rf .vagrant