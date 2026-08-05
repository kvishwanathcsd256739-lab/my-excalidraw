#!/usr/bin/env bash
# =============================================================================
# deploy/oci/deploy-oci.sh — Deployment automation script for OCI Always Free
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[deploy-oci]${NC} $*"; }
warn()    { echo -e "${YELLOW}[deploy-oci]${NC} $*"; }
error()   { echo -e "${RED}[deploy-oci] ERROR:${NC} $*" >&2; exit 1; }
section() { echo -e "\n${BLUE}══ $* ══${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.oci.yml"
ENV_FILE="/opt/excalidraw/.env.production"

section "Loading environment"
[[ -f "$ENV_FILE" ]] || error "Missing $ENV_FILE. Run setup-oci.sh first."
set -a; source "$ENV_FILE"; set +a

[[ -z "${DOMAIN:-}" ]] && error "DOMAIN is not set in $ENV_FILE"

section "1. Updating Repository & Source Files"
git -C "$REPO_DIR" pull origin main || warn "Git pull failed or branch unaligned; proceeding with local working tree."

section "2. Ensuring excalidraw-room image exists"
if ! docker image inspect excalidraw-room:local >/dev/null 2>&1; then
    info "Building excalidraw-room for ARM64..."
    bash "${SCRIPT_DIR}/build-room.sh"
fi

section "3. Configuring Nginx Reverse Proxy"
sed "s/EXCALIDRAW_DOMAIN/${DOMAIN}/g" "${REPO_DIR}/deploy/nginx-proxy.conf" > /opt/excalidraw/nginx-proxy.conf

section "4. Building & Deploying Docker Containers"
docker compose -f "$COMPOSE_FILE" build excalidraw
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

section "5. Verifying Deployment Health"
HEALTH_URL="http://localhost/health"
TIMEOUT=60
INTERVAL=5
ELAPSED=0
HEALTHY=false

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "${HEALTH_URL}" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
        HEALTHY=true
        break
    fi
    echo -n "."
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done
echo ""

if [[ "$HEALTHY" == "true" ]]; then
    info "Health check PASSED!"
else
    error "Health check FAILED! Inspect logs with: docker compose -f $COMPOSE_FILE logs"
fi

section "6. Deployment Complete"
docker compose -f "$COMPOSE_FILE" ps
info "Application live at: https://${DOMAIN}"
