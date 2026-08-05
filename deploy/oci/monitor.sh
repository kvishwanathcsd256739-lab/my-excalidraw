#!/usr/bin/env bash
# =============================================================================
# deploy/oci/monitor.sh — Monitoring script for Excalidraw OCI Always Free
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== SYSTEM RESOURCE MONITORING ===${NC}"
echo -e "Hostname: $(hostname)"
echo -e "Uptime:   $(uptime -p)"
echo ""

echo -e "${GREEN}--- CPU & RAM Usage ---${NC}"
free -h
echo ""

echo -e "${GREEN}--- Disk Usage ---${NC}"
df -h /
echo ""

echo -e "${GREEN}--- Docker Containers Status ---${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo -e "${GREEN}--- Docker Resource Usage ---${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
echo ""

echo -e "${GREEN}--- TLS Certificate Status ---${NC}"
ENV_FILE="/opt/excalidraw/.env.production"
if [[ -f "$ENV_FILE" ]]; then
    DOMAIN=$(grep "^DOMAIN=" "$ENV_FILE" | cut -d= -f2 || true)
    if [[ -n "$DOMAIN" && -f "/opt/excalidraw/certbot/conf/live/${DOMAIN}/fullchain.pem" ]]; then
        EXPIRY=$(openssl x509 -noout -enddate -in "/opt/excalidraw/certbot/conf/live/${DOMAIN}/fullchain.pem" | cut -d= -f2)
        echo "Domain: ${DOMAIN}"
        echo "Cert Expiry: ${EXPIRY}"
    else
        echo "Cert file not yet generated for ${DOMAIN:-domain}."
    fi
fi
