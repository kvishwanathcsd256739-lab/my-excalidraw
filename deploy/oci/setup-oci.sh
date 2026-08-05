#!/usr/bin/env bash
# =============================================================================
# deploy/oci/setup-oci.sh — Bootstrap Ubuntu 24.04 OCI Always Free ARM (A1)
# =============================================================================
#
# Run once on a fresh OCI instance as root (or via sudo):
#   sudo bash deploy/oci/setup-oci.sh
#
# Key OCI Features Covered:
#   1. Fix OCI iptables default DROP rules (vital for ingress HTTP/HTTPS)
#   2. System update + essential tools
#   3. Docker Engine + Docker Compose plugin (official Docker APT repo, ARM64)
#   4. Swap file setup (2 GB)
#   5. Directory structure at /opt/excalidraw
#   6. Fail2Ban SSH protection & security hardening
#   7. systemd service setup
#
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[setup-oci]${NC} $*"; }
warn()  { echo -e "${YELLOW}[setup-oci]${NC} $*"; }
error() { echo -e "${RED}[setup-oci] ERROR:${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && error "This script must be run as root. Use: sudo bash $0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# =============================================================================
# 1. FIX OCI IPTABLES GOTCHA
#
# Canonical Ubuntu images on OCI come with restrictive iptables rules that
# block incoming traffic on ports 80/443 even if OCI Security Lists allow it.
# =============================================================================
info "Configuring iptables for OCI..."
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT || true
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT || true
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 22 -j ACCEPT || true

if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save || true
fi

# =============================================================================
# 2. System update & dependencies
# =============================================================================
info "Updating APT packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

info "Installing required utilities..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    ca-certificates \
    curl \
    fail2ban \
    git \
    gnupg \
    htop \
    jq \
    lsb-release \
    net-tools \
    ufw \
    unzip \
    wget \
    iptables-persistent

# =============================================================================
# 3. Docker Engine & Compose plugin (Official ARM64 Docker repo)
# =============================================================================
info "Installing Docker for ARM64..."

for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker

# Configure Docker daemon log limits & live restore
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF
systemctl reload docker

# =============================================================================
# 4. Firewall (UFW)
# =============================================================================
info "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw limit 22/tcp comment "SSH (rate-limited)"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
ufw --force enable

# =============================================================================
# 5. Fail2Ban
# =============================================================================
info "Configuring Fail2Ban..."
systemctl enable fail2ban
systemctl start fail2ban

# =============================================================================
# 6. Swap File Setup (2 GB)
# =============================================================================
if swapon --show | grep -q '/swapfile'; then
    warn "Swap file already exists. Skipping."
else
    info "Creating 2 GB swap file..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# =============================================================================
# 7. Directory Structure & Permissions
# =============================================================================
info "Setting up /opt/excalidraw directory structure..."
mkdir -p /opt/excalidraw/{logs/nginx,certbot/{conf,www},backups,room-src}

if [[ ! -f /opt/excalidraw/.env.production ]]; then
    if [[ -f "${REPO_DIR}/.env.example" ]]; then
        cp "${REPO_DIR}/.env.example" /opt/excalidraw/.env.production
        chmod 600 /opt/excalidraw/.env.production
        warn "Created /opt/excalidraw/.env.production. Please edit it with real values!"
    fi
fi

# Determine default user (ubuntu on OCI)
TARGET_USER="ubuntu"
if ! id "$TARGET_USER" &>/dev/null; then
    TARGET_USER="$SUDO_USER"
fi

if id "$TARGET_USER" &>/dev/null; then
    chown -R "${TARGET_USER}:${TARGET_USER}" /opt/excalidraw
    usermod -aG docker "$TARGET_USER"
fi

info "OCI Ubuntu Bootstrap Complete!"
