#!/usr/bin/env bash
# =============================================================================
# deploy/oci/build-room.sh — Build excalidraw-room natively for ARM64 on OCI
# =============================================================================
#
# Clones https://github.com/excalidraw/excalidraw-room and builds a local
# native ARM64 Docker image: `excalidraw-room:local`
#
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[build-room]${NC} $*"; }
error() { echo -e "${RED}[build-room] ERROR:${NC} $*" >&2; exit 1; }

ROOM_DIR="/opt/excalidraw/room-src"

info "Building excalidraw-room for ARM64..."

if [ ! -d "$ROOM_DIR/.git" ]; then
    info "Cloning excalidraw-room repository..."
    git clone https://github.com/excalidraw/excalidraw-room.git "$ROOM_DIR"
else
    info "Updating excalidraw-room repository..."
    git -C "$ROOM_DIR" pull
fi

info "Building Docker image: excalidraw-room:local..."
docker build -t excalidraw-room:local "$ROOM_DIR"

info "excalidraw-room:local ARM64 build successful!"
