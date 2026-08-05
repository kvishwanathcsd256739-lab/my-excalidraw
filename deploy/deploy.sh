#!/usr/bin/env bash
# =============================================================================
# deploy/deploy.sh — Deploy / update Excalidraw on EC2
# =============================================================================
#
# Usage:
#   bash deploy/deploy.sh [IMAGE_TAG]
#
#   IMAGE_TAG: optional. Defaults to value in .env.production or "latest".
#              Pass a specific tag for pinned deployments:
#                bash deploy/deploy.sh abc1234   # deploy git SHA abc1234
#
# What this script does:
#   1.  Load /opt/excalidraw/.env.production
#   2.  Log in to AWS ECR (using instance profile OR env var credentials)
#   3.  Pull the new Excalidraw image from ECR
#   4.  Pull latest excalidraw-room from Docker Hub
#   5.  Start/update all services with docker compose up -d
#   6.  Wait for health checks to pass (60s timeout)
#   7.  If unhealthy → automatic rollback to the previous image
#
# Prerequisites:
#   - setup.sh must have been run
#   - certbot-init.sh must have been run (TLS certs must exist)
#   - /opt/excalidraw/.env.production must be fully configured
#   - EC2 instance must have an IAM role with AmazonEC2ContainerRegistryReadOnly
#     (OR AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY set in .env.production)
#
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[deploy]${NC} $*"; }
warn()    { echo -e "${YELLOW}[deploy]${NC} $*"; }
error()   { echo -e "${RED}[deploy] ERROR:${NC} $*" >&2; exit 1; }
section() { echo -e "\n${BLUE}══ $* ══${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.ec2.yml"
ENV_FILE="/opt/excalidraw/.env.production"

# =============================================================================
# 1. Load environment
# =============================================================================
section "Loading configuration"
[[ -f "$ENV_FILE" ]] || error "Missing $ENV_FILE — run setup.sh and fill in your credentials."
set -a; source "$ENV_FILE"; set +a

# Allow IMAGE_TAG override via command-line argument
[[ -n "${1:-}" ]] && IMAGE_TAG="$1"
IMAGE_TAG="${IMAGE_TAG:-latest}"

[[ -z "${DOMAIN:-}" ]]          && error "DOMAIN is not set in $ENV_FILE"

USE_ECR=true
if [[ -z "${ECR_REGISTRY:-}" ]]; then
    warn "ECR_REGISTRY is not set in $ENV_FILE. Switching to local container build mode."
    USE_ECR=false
    COMPOSE_FILE="${SCRIPT_DIR}/oci/docker-compose.oci.yml"
fi

info "Domain:    https://${DOMAIN}"
info "Compose:   ${COMPOSE_FILE}"

# =============================================================================
# 2. Check TLS certificates exist
# =============================================================================
section "Checking TLS certificates"
CERT_FILE="/opt/excalidraw/certbot/conf/live/${DOMAIN}/fullchain.pem"
if [[ ! -f "$CERT_FILE" ]]; then
    error "TLS certificate not found at ${CERT_FILE}."$'\n'"Run deploy/certbot-init.sh first."
fi
EXPIRY=$(openssl x509 -noout -enddate -in "$CERT_FILE" | cut -d= -f2)
info "Certificate expires: ${EXPIRY}"

# =============================================================================
# 3. Pull or Build Images
# =============================================================================
if [[ "$USE_ECR" == "true" ]]; then
    section "Logging in to AWS ECR"
    aws ecr get-login-password --region "${AWS_REGION:-us-east-1}" \
        | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
    info "ECR login successful."

    section "Pulling images from ECR"
    ECR_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY:-excalidraw}:${IMAGE_TAG}"
    docker pull "${ECR_IMAGE}"
    docker pull excalidraw/excalidraw-room:latest
else
    section "Building containers locally"
    if ! docker image inspect excalidraw-room:local >/dev/null 2>&1; then
        info "Building excalidraw-room for local deployment..."
        bash "${SCRIPT_DIR}/oci/build-room.sh"
    fi
    docker compose -f "${COMPOSE_FILE}" build excalidraw
fi

# =============================================================================
# 5. Capture currently running image tag for rollback
# =============================================================================
PREV_IMAGE=$(docker inspect excalidraw-app --format '{{.Config.Image}}' 2>/dev/null || echo "")
info "Previous image: ${PREV_IMAGE:-none (first deploy)}"

# =============================================================================
# 6. Inject domain into nginx-proxy.conf
# =============================================================================
section "Configuring nginx-proxy"
NGINX_CONF_SRC="${SCRIPT_DIR}/nginx-proxy.conf"
NGINX_CONF_LIVE="/opt/excalidraw/nginx-proxy.conf"

# Replace EXCALIDRAW_DOMAIN placeholder with the actual domain
sed "s/EXCALIDRAW_DOMAIN/${DOMAIN}/g" "${NGINX_CONF_SRC}" > "${NGINX_CONF_LIVE}"
info "nginx-proxy.conf → ${NGINX_CONF_LIVE} (domain: ${DOMAIN})"

# Update the compose file mount to use the live config
export NGINX_CONF_LIVE

# =============================================================================
# 7. Start / update services
# =============================================================================
section "Starting services"

# Export IMAGE_TAG so docker compose can read it from the environment
export IMAGE_TAG

docker compose \
    -f "${COMPOSE_FILE}" \
    up -d \
    --remove-orphans \
    --pull never   # Images already pulled above — don't pull again

info "Containers started. Waiting for health checks..."

# =============================================================================
# 8. Health check with timeout and rollback
# =============================================================================
section "Verifying deployment health"

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
    info "Health check passed! (${ELAPSED}s)"
else
    warn "Health check FAILED after ${TIMEOUT}s. HTTP code: ${HTTP_CODE}"

    # ── Rollback ──────────────────────────────────────────────────────────────
    if [[ -n "$PREV_IMAGE" ]]; then
        warn "Rolling back to previous image: ${PREV_IMAGE}"
        export IMAGE_TAG="${PREV_IMAGE##*:}"  # extract tag from image string
        docker compose -f "${COMPOSE_FILE}" up -d --no-deps excalidraw

        sleep 10
        ROLLBACK_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "${HEALTH_URL}" 2>/dev/null || echo "000")
        if [[ "$ROLLBACK_CODE" == "200" ]]; then
            warn "Rollback successful. Previous version is running."
        else
            error "Rollback also failed (HTTP ${ROLLBACK_CODE}). Manual intervention required."$'\n'"Run: docker compose -f ${COMPOSE_FILE} logs"
        fi
    else
        error "No previous image to roll back to. Check logs:"$'\n'"docker compose -f ${COMPOSE_FILE} logs"
    fi
    exit 1
fi

# =============================================================================
# 9. Show status
# =============================================================================
section "Deployment complete"

echo ""
docker compose -f "${COMPOSE_FILE}" ps
echo ""
info "Application URL:  https://${DOMAIN}"
info "Health endpoint:  https://${DOMAIN}/health"
info "Version endpoint: https://${DOMAIN}/version.json"
echo ""
info "View logs: docker compose -f ${COMPOSE_FILE} logs -f"
info "Status:    docker compose -f ${COMPOSE_FILE} ps"
echo ""

# =============================================================================
# 10. Post-deploy checks
# =============================================================================
section "Post-deploy checks"

# Check HTTPS is working (requires curl with TLS)
HTTPS_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "https://${DOMAIN}/health" 2>/dev/null || echo "000")
if [[ "$HTTPS_CODE" == "200" ]]; then
    info "HTTPS OK: https://${DOMAIN}/health returned 200"
else
    warn "HTTPS check returned: ${HTTPS_CODE} (may be DNS propagation delay if first deploy)"
fi

# Check HTTP redirects to HTTPS
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://${DOMAIN}/" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "301" ]]; then
    info "HTTP redirect OK: http://${DOMAIN}/ → 301 (→ HTTPS)"
else
    warn "HTTP redirect returned: ${HTTP_CODE} (expected 301)"
fi

# Show TLS certificate details
CERT_EXPIRY=$(echo | openssl s_client -connect "${DOMAIN}:443" -servername "${DOMAIN}" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "check failed")
info "TLS certificate expires: ${CERT_EXPIRY}"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment successful!  Image: ${IMAGE_TAG}${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
