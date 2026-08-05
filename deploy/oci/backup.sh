#!/usr/bin/env bash
# =============================================================================
# deploy/oci/backup.sh — Backup script for Excalidraw OCI Deployment
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'

BACKUP_DIR="/opt/excalidraw/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TARGET_ARCHIVE="${BACKUP_DIR}/excalidraw_backup_${TIMESTAMP}.tar.gz"

echo -e "${GREEN}[backup] Starting backup...${NC}"

mkdir -p "$BACKUP_DIR"

tar -czf "$TARGET_ARCHIVE" \
    /opt/excalidraw/.env.production \
    /opt/excalidraw/certbot/conf \
    /opt/excalidraw/nginx-proxy.conf 2>/dev/null || true

echo -e "${GREEN}[backup] Backup archive created: ${TARGET_ARCHIVE}${NC}"

# Retain backups for 14 days
find "$BACKUP_DIR" -type f -name "excalidraw_backup_*.tar.gz" -mtime +14 -exec rm -f {} \;
echo -e "${GREEN}[backup] Older backups cleaned up.${NC}"
