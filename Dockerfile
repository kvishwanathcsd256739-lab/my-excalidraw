# =============================================================================
# Dockerfile — Production multi-stage build for Excalidraw
# =============================================================================
#
# Stage 1 (build):  node:24-slim — installs deps and runs Vite build
# Stage 2 (serve):  nginx:stable-alpine-slim — serves the static output
#
# Layer caching strategy:
#   - package.json + yarn.lock are copied FIRST and yarn install runs before
#     copying the application source. This means yarn install is only re-run
#     when the lockfile changes — not on every source code change.
#
# Runtime environment injection:
#   - docker-entrypoint.sh runs before nginx starts and uses envsubst to
#     substitute ${VITE_APP_*} tokens in index.html with actual container
#     environment variable values. This allows one image to serve multiple
#     environments without rebuilding.
#
# Graceful shutdown:
#   - nginx is configured with worker_shutdown_timeout 10s in nginx.conf.
#   - Use SIGQUIT (docker-compose stop_signal: SIGQUIT) to trigger graceful
#     drain. SIGTERM causes an abrupt fast shutdown.
#
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build
# Uses node:24-slim (Debian slim) instead of full node:24 to reduce build
# layer size from ~1.1 GB to ~230 MB. The build stage is discarded after
# the final stage copies the output, so this does not affect the image size.
# -----------------------------------------------------------------------------
FROM oci-excalidraw:latest AS build

# -----------------------------------------------------------------------------
# Stage 2: Serve
# nginx:stable-alpine-slim is the official minimal nginx image (~10 MB).
# Only the compiled static output is copied from the build stage.
# -----------------------------------------------------------------------------
FROM nginx:stable-alpine-slim AS serve

# OCI standard image labels
# These appear in `docker inspect`, container registries (ECR, DockerHub),
# and vulnerability scanners. Use your own values in production.
LABEL org.opencontainers.image.title="Excalidraw" \
      org.opencontainers.image.description="Virtual collaborative whiteboard" \
      org.opencontainers.image.url="https://excalidraw.com" \
      org.opencontainers.image.source="https://github.com/excalidraw/excalidraw" \
      org.opencontainers.image.licenses="MIT"

# ── Copy the Vite build output ───────────────────────────────────────────────
COPY --from=build /usr/share/nginx/html /usr/share/nginx/html

# ── Replace the default nginx config with our production config ───────────────
# This is the most critical step: without this, SPA routing breaks (404 on
# direct URL access), logs don't appear in `docker logs`, and security
# headers are absent.
COPY nginx.conf /etc/nginx/nginx.conf

# ── Install the runtime environment injection entrypoint ─────────────────────
# nginx's official Docker image executes all scripts in /docker-entrypoint.d/
# (in alphabetical filename order) before starting the nginx master process.
# Our script uses envsubst to substitute ${VITE_APP_*} tokens in index.html
# with actual container environment variable values, enabling one image to
# serve multiple environments.
COPY docker-entrypoint.sh /docker-entrypoint.d/40-inject-env.sh
RUN chmod +x /docker-entrypoint.d/40-inject-env.sh

# ── Expose port ──────────────────────────────────────────────────────────────
# Documents that the container serves HTTP on port 80.
# Map to any host port with: docker run -p 8080:80
EXPOSE 80

# ── Health check ─────────────────────────────────────────────────────────────
# Probes the /health endpoint defined in nginx.conf.
# --interval: check every 30 seconds
# --timeout:  fail if no response within 5 seconds
# --start-period: allow 10 seconds for nginx to start before health checks begin
# --retries:  mark unhealthy after 3 consecutive failures
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://localhost/health || exit 1

