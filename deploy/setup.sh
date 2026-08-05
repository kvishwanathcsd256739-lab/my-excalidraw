#!/usr/bin/env bash
# =============================================================================
# deploy/setup.sh — Bootstrap Ubuntu 24.04 EC2 for Excalidraw
# =============================================================================
#
# Run once on a fresh EC2 instance as root (or via sudo):
#   sudo bash deploy/setup.sh
#
# What this script does:
#   1.  System update + required APT packages
#   2.  Docker Engine + Compose plugin (official Docker repo)
#   3.  AWS CLI v2 (for ECR image pulls)
#   4.  UFW firewall (ports 22, 80, 443 only)
#   5.  fail2ban (SSH brute-force protection)
#   6.  2 GB swap file (CRITICAL for t2.micro — 1 GB RAM)
#   7.  /opt/excalidraw/ directory structure
#   8.  Docker daemon config (log rotation, live-restore)
#   9.  Add ubuntu user to docker group
#   10. Register excalidraw.service with systemd
#
# After running this script:
#   - Copy .env.example → /opt/excalidraw/.env.production and fill in values
#   - Run deploy/certbot-init.sh to get the first TLS certificate
#   - Run deploy/deploy.sh to start the application
#
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn()  { echo -e "${YELLOW}[setup]${NC} $*"; }
error() { echo -e "${RED}[setup] ERROR:${NC} $*" >&2; exit 1; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "This script must be run as root. Use: sudo bash $0"

# ── Script directory (so paths work regardless of where it's run from) ────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# 1. System update
# =============================================================================
info "Updating package index and upgrading system packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# =============================================================================
# 2. Required APT packages
# =============================================================================
info "Installing required packages..."
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
    wget

# =============================================================================
# 3. Docker Engine + Compose plugin (official Docker APT repo)
#
# Why not `snap install docker` or `apt install docker.io`?
#   - snap: sandboxed, causes permission issues with volume mounts
#   - docker.io (Ubuntu repo): significantly older versions (e.g. 24.x vs 27.x)
# =============================================================================
info "Installing Docker Engine from the official Docker repo..."

# Remove any old/conflicting Docker packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker APT repository
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

# Enable and start Docker
systemctl enable docker
systemctl start docker

info "Docker version: $(docker --version)"
info "Docker Compose version: $(docker compose version)"

# =============================================================================
# 4. Docker daemon configuration
#
# - log-driver + log-opts: prevent /var/lib/docker/containers from filling the
#   30 GB free-tier EBS disk. Each container keeps max 30 MB of logs.
# - live-restore: containers keep running when the Docker daemon restarts
#   (e.g., during a Docker upgrade). Prevents service interruption.
# =============================================================================
info "Configuring Docker daemon..."
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
# 5. AWS CLI v2
#
# Required for: aws ecr get-login-password (ECR image pulls)
# Installed from the official AWS bundle (not pip, not apt — both lag behind).
# =============================================================================
info "Installing AWS CLI v2..."
if command -v aws &>/dev/null; then
    warn "AWS CLI already installed: $(aws --version). Skipping."
else
    TMPDIR=$(mktemp -d)
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o "${TMPDIR}/awscliv2.zip"
    unzip -q "${TMPDIR}/awscliv2.zip" -d "${TMPDIR}"
    "${TMPDIR}/aws/install"
    rm -rf "${TMPDIR}"
    info "AWS CLI version: $(aws --version)"
fi

# =============================================================================
# 6. UFW Firewall
#
# Free-tier security posture:
#   - Port 22  (SSH):   allow but RATE-LIMITED (blocks brute force at OS level)
#   - Port 80  (HTTP):  allow (nginx redirect to HTTPS + ACME challenge)
#   - Port 443 (HTTPS): allow (Excalidraw SPA)
#   - Everything else:  DENY by default
#
# Note: AWS Security Groups are the primary firewall (VPC level).
# UFW adds defence-in-depth at the OS level.
#
# IMPORTANT: SSH (22) is enabled FIRST to prevent locking yourself out.
# =============================================================================
info "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH: rate-limit blocks sources that attempt > 6 connections in 30 seconds
ufw limit 22/tcp comment "SSH (rate-limited)"

# HTTP: needed for Let's Encrypt ACME challenge and HTTP→HTTPS redirect
ufw allow 80/tcp comment "HTTP"

# HTTPS: primary application port
ufw allow 443/tcp comment "HTTPS"

# Enable UFW (--force skips the interactive "are you sure?" prompt)
ufw --force enable

info "UFW status:"
ufw status verbose

# =============================================================================
# 7. fail2ban (SSH brute-force protection)
#
# Works alongside UFW's rate limit. fail2ban bans IPs that have too many
# failed SSH login attempts. Default config bans for 10 minutes after 5 fails.
# =============================================================================
info "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# =============================================================================
# 8. Swap file (CRITICAL for t2.micro)
#
# t2.micro has 1 GB RAM. Without swap:
#   - excalidraw-room (Node.js): ~120 MB
#   - excalidraw SPA (nginx):    ~30 MB
#   - nginx-proxy:               ~30 MB
#   - Docker daemon:             ~100 MB
#   - Ubuntu OS:                 ~300 MB
#   - Total:                     ~580 MB — leaves < 400 MB headroom
#
# Under any load spike, OOM killer will terminate containers.
# A 2 GB swap file gives a safety margin at ~0 cost.
#
# vm.swappiness=10: prefer RAM over swap under normal load,
# only use swap as a last resort.
# =============================================================================
if swapon --show | grep -q '/swapfile'; then
    warn "Swap file already exists. Skipping swap setup."
else
    info "Creating 2 GB swap file for t2.micro..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # Tune swappiness: 10 means only use swap when RAM is 90% full
    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf

    # Reduce vfs_cache_pressure: keep filesystem cache in RAM longer
    sysctl vm.vfs_cache_pressure=50
    echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf

    info "Swap created: $(swapon --show)"
fi

# =============================================================================
# 9. Directory structure
#
# /opt/excalidraw/
# ├── repo/                  ← git clone of this repository
# ├── .env.production        ← real credentials (fill in manually)
# ├── logs/nginx/            ← nginx access/error logs (persistent volume)
# ├── certbot/
# │   ├── conf/              ← Let's Encrypt certs (persistent, BACK THIS UP)
# │   └── www/               ← ACME HTTP challenge webroot
# └── backups/               ← periodic config backups
# =============================================================================
info "Creating /opt/excalidraw directory structure..."
mkdir -p /opt/excalidraw/{logs/nginx,certbot/{conf,www},backups}

# Copy .env.example to /opt/excalidraw if it doesn't already exist there
if [[ ! -f /opt/excalidraw/.env.production ]]; then
    if [[ -f "${REPO_DIR}/.env.example" ]]; then
        cp "${REPO_DIR}/.env.example" /opt/excalidraw/.env.production
        warn "Copied .env.example → /opt/excalidraw/.env.production"
        warn "IMPORTANT: Edit /opt/excalidraw/.env.production with your real values!"
    else
        warn ".env.example not found. Create /opt/excalidraw/.env.production manually."
    fi
fi

# Set ownership so ubuntu user (default EC2 user) can manage files without sudo
chown -R ubuntu:ubuntu /opt/excalidraw

# =============================================================================
# 10. Add ubuntu user to docker group
#
# This allows the ubuntu user to run `docker` commands without sudo.
# The group membership takes effect on next login (or use `newgrp docker`).
# =============================================================================
info "Adding ubuntu user to docker group..."
usermod -aG docker ubuntu

# =============================================================================
# 11. Install systemd service
# =============================================================================
if [[ -f "${SCRIPT_DIR}/excalidraw.service" ]]; then
    info "Installing excalidraw.service systemd unit..."
    cp "${SCRIPT_DIR}/excalidraw.service" /etc/systemd/system/excalidraw.service
    systemctl daemon-reload
    systemctl enable excalidraw.service
    info "excalidraw.service enabled (will start on next boot after deploy.sh is run)"
else
    warn "deploy/excalidraw.service not found. Install it manually after setup."
fi

# =============================================================================
# 12. Logrotate for application logs
# =============================================================================
info "Configuring logrotate for /opt/excalidraw/logs..."
cat > /etc/logrotate.d/excalidraw <<'EOF'
/opt/excalidraw/logs/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        # Signal nginx-proxy container to reopen log files after rotation
        docker kill --signal=USR1 excalidraw-proxy 2>/dev/null || true
    endscript
}
EOF

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Edit credentials:"
echo "     nano /opt/excalidraw/.env.production"
echo "     # Set VITE_APP_FIREBASE_CONFIG, VITE_APP_WS_SERVER_URL,"
echo "     # AWS_ACCOUNT_ID, AWS_REGION, ECR_REPOSITORY, DOMAIN"
echo ""
echo "  2. Get TLS certificate (first time only):"
echo "     bash ${SCRIPT_DIR}/certbot-init.sh"
echo ""
echo "  3. Deploy the application:"
echo "     bash ${SCRIPT_DIR}/deploy.sh"
echo ""
echo "  IMPORTANT: Log out and back in for docker group to take effect,"
echo "  or run: newgrp docker"
echo ""
echo -e "${YELLOW}  ⚠  Swap: $(swapon --show | tail -1)${NC}"
echo -e "${YELLOW}  ⚠  UFW: $(ufw status | head -1)${NC}"
echo ""
