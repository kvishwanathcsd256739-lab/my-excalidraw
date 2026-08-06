#!/bin/sh
# =============================================================================
# docker-entrypoint.sh
# =============================================================================
#
# PURPOSE:
#   Inject runtime environment variables into index.html before nginx starts.
#
# PROBLEM SOLVED:
#   Vite bakes all VITE_APP_* variables into the JS bundle at build time.
#   This makes the Docker image environment-specific and requires a full
#   rebuild to change any config (e.g., pointing to a different WebSocket
#   server or Firebase project).
#
# HOW IT WORKS:
#   1. index.html contains a placeholder script block with ${VAR} tokens.
#   2. This script uses envsubst to replace those tokens with actual values
#      from the container's environment variables.
#   3. The result is written back to index.html in-place.
#   4. nginx then serves the rewritten index.html.
#
# EXECUTION:
#   This script is placed in /docker-entrypoint.d/ which nginx's official
#   Docker image executes automatically (in alphabetical order) before
#   starting the nginx master process. No custom CMD is needed.
#
# FALLBACK:
#   Variables that are not set in the container environment will be replaced
#   with empty strings by envsubst. The app handles missing optional vars
#   gracefully (features are hidden/disabled).
#
#   REQUIRED variables (collaboration and storage will break if unset):
#     - VITE_APP_FIREBASE_CONFIG
#     - VITE_APP_BACKEND_V2_GET_URL
#     - VITE_APP_BACKEND_V2_POST_URL
#     - VITE_APP_WS_SERVER_URL
#
# =============================================================================

set -e

INDEX_HTML="/usr/share/nginx/html/index.html"

# Verify the file exists (sanity check — should never fail in normal builds)
if [ ! -f "$INDEX_HTML" ]; then
    echo "[entrypoint] ERROR: $INDEX_HTML not found. Build may have failed." >&2
    exit 1
fi

echo "[entrypoint] Injecting runtime environment variables into index.html..."

# List of VITE_APP_* variables to substitute.
# envsubst only replaces variables explicitly listed here — it will NOT
# accidentally replace shell variables like $PATH or $HOME in the HTML.
VARS_TO_SUBSTITUTE='$VITE_APP_FIREBASE_CONFIG\
$VITE_APP_BACKEND_V2_GET_URL\
$VITE_APP_BACKEND_V2_POST_URL\
$VITE_APP_WS_SERVER_URL\
$VITE_APP_LIBRARY_URL\
$VITE_APP_LIBRARY_BACKEND\
$VITE_APP_AI_BACKEND\
$VITE_APP_PLUS_LP\
$VITE_APP_PLUS_APP\
$VITE_APP_PLUS_EXPORT_PUBLIC_KEY\
$VITE_APP_DISABLE_SENTRY'

# Perform substitution into a temp file, then atomically replace the original.
# Using a temp file avoids a partial read if nginx starts concurrently.
TMPFILE=$(mktemp)

envsubst "$VARS_TO_SUBSTITUTE" < "$INDEX_HTML" > "$TMPFILE"

# Verify substitution produced a non-empty file
if [ ! -s "$TMPFILE" ]; then
    echo "[entrypoint] ERROR: envsubst produced an empty file. Aborting." >&2
    rm -f "$TMPFILE"
    exit 1
fi

mv "$TMPFILE" "$INDEX_HTML"
chmod 644 "$INDEX_HTML"

echo "[entrypoint] Environment variable injection complete."

# Log which variables were provided (values redacted for security)
echo "[entrypoint] Environment summary:"
echo "[entrypoint]   VITE_APP_WS_SERVER_URL       = ${VITE_APP_WS_SERVER_URL:-(not set)}"
echo "[entrypoint]   VITE_APP_BACKEND_V2_GET_URL   = ${VITE_APP_BACKEND_V2_GET_URL:-(not set)}"
echo "[entrypoint]   VITE_APP_BACKEND_V2_POST_URL  = ${VITE_APP_BACKEND_V2_POST_URL:-(not set)}"
echo "[entrypoint]   VITE_APP_AI_BACKEND           = ${VITE_APP_AI_BACKEND:-(not set)}"
echo "[entrypoint]   VITE_APP_PLUS_LP              = ${VITE_APP_PLUS_LP:-(not set)}"
echo "[entrypoint]   VITE_APP_PLUS_APP             = ${VITE_APP_PLUS_APP:-(not set)}"
echo "[entrypoint]   VITE_APP_FIREBASE_CONFIG       = ${VITE_APP_FIREBASE_CONFIG:+(set — value redacted)}"
echo "[entrypoint]   VITE_APP_FIREBASE_CONFIG       = ${VITE_APP_FIREBASE_CONFIG:-(not set — collaboration will not work)}"

# Warn if critical variables are missing
MISSING_REQUIRED=0
for VAR in VITE_APP_FIREBASE_CONFIG VITE_APP_WS_SERVER_URL VITE_APP_BACKEND_V2_GET_URL VITE_APP_BACKEND_V2_POST_URL; do
    eval "VAL=\${$VAR}"
    if [ -z "$VAL" ]; then
        echo "[entrypoint] WARNING: Required variable $VAR is not set." >&2
        MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
    fi
done

if [ "$MISSING_REQUIRED" -gt 0 ]; then
    echo "[entrypoint] WARNING: $MISSING_REQUIRED required variable(s) missing." >&2
    echo "[entrypoint] The app will start but collaboration/sharing features will not work." >&2
fi

# nginx's /docker-entrypoint.d/ runner will now start the nginx master process.
