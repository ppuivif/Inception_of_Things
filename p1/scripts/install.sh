#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

chmod +x "$0"

# Restart the script as root if needed
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0"
fi

export DEBIAN_FRONTEND=noninteractive

# Install basic tools often missing from a minimal Debian (netinst) installation
apt-get update
apt-get install -y ca-certificates curl gnupg

# Add HashiCorp repository: provides Vagrant 2.4.x (required for VirtualBox 7.2)
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
chmod a+r /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com trixie main" \
    > /etc/apt/sources.list.d/hashicorp.list

# Add Debian Backports repository: provides dependencies required by VirtualBox
cat > /etc/apt/sources.list.d/trixie-backports.sources <<EOF
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
EOF

# Add Debian Fast Track repository: provides the VirtualBox package
apt-get update
apt-get install -y fasttrack-archive-keyring

cat > /etc/apt/sources.list.d/trixie-fasttrack.sources <<EOF
Types: deb
URIs: https://fasttrack.debian.net/debian-fasttrack
Suites: trixie-fasttrack trixie-backports-staging
Components: main contrib
Signed-By: /usr/share/keyrings/fasttrack-archive-keyring.gpg
EOF

apt-get update

# Install kernel headers and build tools (DKMS builds VirtualBox modules)
apt-get install -y "linux-headers-$(uname -r)" || true
apt-get install -y linux-headers-amd64 build-essential dkms

# Install Vagrant, then VirtualBox
apt-get install -y vagrant
apt-get install -y virtualbox virtualbox-dkms

# Disable KVM to let VirtualBox use VT-x (now and after reboot)
cat > /etc/modprobe.d/blacklist-kvm.conf <<'EOF'
blacklist kvm
blacklist kvm_intel
blacklist kvm_amd
EOF
modprobe -r kvm_intel kvm_amd 2>/dev/null || true
modprobe -r kvm              2>/dev/null || true


# Load VirtualBox modules now and at every boot
cat > /etc/modules-load.d/virtualbox.conf <<'EOF'
vboxdrv
vboxnetadp
vboxnetflt
EOF
modprobe vboxdrv
modprobe vboxnetadp
modprobe vboxnetflt

echo -e "${GREEN}/nInstallation done.${NC}"
