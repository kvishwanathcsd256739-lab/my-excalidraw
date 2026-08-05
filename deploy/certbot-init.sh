#!/usr/bin/env bash
# =============================================================================
# deploy/certbot-init.sh — First-time Let's Encrypt certificate acquisition
# =============================================================================
#
# Run ONCE on first deployment, BEFORE starting the full stack.
# The full stack (nginx-proxy) requires TLS certificates to start on port 443.
# This script bootstraps the chicken-and-egg problem:
#
#   1. Starts a temporary HTTP-only nginx container on port 80
#   2. Uses the webroot method to complete the ACME HTTP-01 challenge
#   3. Gets a real certificate from Let's Encrypt
#   4. Generates ssl-dhparams.pem (required by nginx-proxy.conf)
#   5. Stops the temporary container
#
# After this script succeeds, run deploy/deploy.sh to start the full stack.
#
# Requirements:
#   - DNS A record for $DOMAIN must already point to this EC2 instance's IP
#   - Port 80 must be open (UFW + Security Group)
#   - /opt/excalidraw/.env.production must have DOMAIN set
#   - Docker must be running (run setup.sh first)
#
# Usage:
#   sudo bash deploy/certbot-init.sh
#
# Let's Encrypt rate limits:
#   - 5 CERTIFICATES per registered domain per week
#   - 50 DOMAINS per certificate
#   - If you hit the limit, use --staging flag to test with a test cert
#
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[certbot-init]${NC} $*"; }
warn()  { echo -e "${YELLOW}[certbot-init]${NC} $*"; }
error() { echo -e "${RED}[certbot-init] ERROR:${NC} $*" >&2; exit 1; }

# ── Load environment ──────────────────────────────────────────────────────────
ENV_FILE="/opt/excalidraw/.env.production"
[[ -f "$ENV_FILE" ]] || error ".env.production not found at $ENV_FILE. Run setup.sh first."

# shellcheck source=/dev/null
set -a; source "$ENV_FILE"; set +a

[[ -z "${DOMAIN:-}" ]]         && error "DOMAIN is not set in $ENV_FILE"
[[ -z "${CERTBOT_EMAIL:-}" ]]  && error "CERTBOT_EMAIL is not set in $ENV_FILE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTBOT_CONF="/opt/excalidraw/certbot/conf"
CERTBOT_WWW="/opt/excalidraw/certbot/www"

# ── Check if certificate already exists ──────────────────────────────────────
if [[ -d "${CERTBOT_CONF}/live/${DOMAIN}" ]]; then
    warn "Certificate for ${DOMAIN} already exists."
    warn "If you need to force renewal, use: certbot renew --force-renewal"
    warn "Skipping certificate acquisition."
    exit 0
fi

info "Starting certificate acquisition for: ${DOMAIN}"
info "Contact email: ${CERTBOT_EMAIL}"

# ── Check DNS resolution ──────────────────────────────────────────────────────
info "Checking DNS resolution for ${DOMAIN}..."
RESOLVED_IP=$(dig +short "${DOMAIN}" A 2>/dev/null | head -1 || true)
EC2_IP=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")

if [[ -z "$RESOLVED_IP" ]]; then
    error "DNS: ${DOMAIN} does not resolve. Set an A record pointing to your EC2 IP (${EC2_IP}) first."
fi

if [[ "$RESOLVED_IP" != "$EC2_IP" && "$EC2_IP" != "unknown" ]]; then
    warn "DNS: ${DOMAIN} resolves to ${RESOLVED_IP} but this EC2 is ${EC2_IP}"
    warn "If this is wrong, the ACME challenge will fail."
    read -r -p "Continue anyway? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

info "DNS OK: ${DOMAIN} → ${RESOLVED_IP}"

# ── Start a temporary HTTP-only nginx to serve the ACME challenge ─────────────
#
# This minimal nginx container only serves the ACME challenge path.
# It is stopped immediately after certbot succeeds.
# The webroot path (/var/www/certbot) is shared with the certbot container.
#
info "Starting temporary HTTP-only nginx for ACME challenge..."

docker run -d \
    --name certbot-nginx-tmp \
    --rm \
    -p 80:80 \
    -v "${CERTBOT_WWW}:/var/www/certbot:rw" \
    nginx:stable-alpine-slim \
    sh -c 'echo "server { listen 80; location /.well-known/acme-challenge/ { root /var/www/certbot; } location / { return 200 ok; } }" > /etc/nginx/conf.d/default.conf && nginx -g "daemon off;"'

# Give nginx a moment to start
sleep 3

# ── Acquire the certificate ───────────────────────────────────────────────────
info "Requesting certificate from Let's Encrypt..."
info "(This requires a working internet connection and port 80 open)"

# Use --staging for testing (comment out --staging for production)
# Staging certs are trusted by browsers only with --staging flag
# Once you have confirmed staging works, re-run without --staging

CERTBOT_ARGS=(
    --non-interactive
    --webroot
    --webroot-path=/var/www/certbot
    --email "${CERTBOT_EMAIL}"
    --agree-tos
    --no-eff-email
    -d "${DOMAIN}"
    --cert-name "${DOMAIN}"
)

# Uncomment to add www subdomain as a Subject Alternative Name:
# CERTBOT_ARGS+=(-d "www.${DOMAIN}")

# Uncomment for staging (test run — cert will not be trusted by browsers):
# CERTBOT_ARGS+=(--staging)

docker run --rm \
    -v "${CERTBOT_CONF}:/etc/letsencrypt" \
    -v "${CERTBOT_WWW}:/var/www/certbot" \
    certbot/certbot:latest \
    certonly "${CERTBOT_ARGS[@]}"

CERT_EXIT=$?

# ── Stop the temporary nginx ──────────────────────────────────────────────────
info "Stopping temporary nginx container..."
docker stop certbot-nginx-tmp 2>/dev/null || true

[[ $CERT_EXIT -ne 0 ]] && error "certbot failed with exit code ${CERT_EXIT}. Check the output above."

# ── Generate ssl-dhparams.pem ─────────────────────────────────────────────────
# Required by the ssl_dhparam directive in nginx-proxy.conf.
# This is a 2048-bit Diffie-Hellman parameter file for forward secrecy.
# Generation takes 1-3 minutes on t2.micro.
DH_PARAMS="${CERTBOT_CONF}/ssl-dhparams.pem"
if [[ ! -f "$DH_PARAMS" ]]; then
    info "Generating ssl-dhparams.pem (this takes ~1 minute on t2.micro)..."
    openssl dhparam -out "$DH_PARAMS" 2048
    info "ssl-dhparams.pem generated."
else
    info "ssl-dhparams.pem already exists. Skipping generation."
fi

# ── Verify certificate ────────────────────────────────────────────────────────
CERT_FILE="${CERTBOT_CONF}/live/${DOMAIN}/fullchain.pem"
if [[ -f "$CERT_FILE" ]]; then
    info "Certificate acquired successfully!"
    EXPIRY=$(openssl x509 -noout -dates -in "$CERT_FILE" | grep notAfter | cut -d= -f2)
    info "Certificate expires: ${EXPIRY}"
    info "Certificate path: ${CERT_FILE}"
else
    error "Certificate file not found at ${CERT_FILE}. Something went wrong."
fi

# ── Next steps ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Certificate acquisition complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Next step — start the full production stack:"
echo ""
echo "  bash ${SCRIPT_DIR}/deploy.sh"
echo ""
echo "  The certbot service in docker-compose.ec2.yml will automatically"
echo "  renew the certificate every 12 hours (renews when < 30 days remain)."
echo ""
