#!/bin/sh
set -euo pipefail

# Configuration with defaults
PLEX_TOKEN="${PLEX_TOKEN:?PLEX_TOKEN is required}"
PLEX_BRANCH="${PLEX_BRANCH:-public}"
PLEX_PROTOCOL="${PLEX_PROTOCOL:-http}"
PLEX_IP="${PLEX_IP:-127.0.0.1}"
PLEX_PORT="${PLEX_PORT:-32400}"
PLEX_CONTAINER_NAME="${PLEX_CONTAINER_NAME:-plex}"
FORCE_UPDATE="${FORCE_UPDATE:-false}"
INTERVAL="${INTERVAL:-360}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Startup validation
[ "$INTERVAL" -lt 5 ] && { log "ERROR - Interval must be at least 5 minutes" >&2; exit 1; }

for cmd in curl jq docker; do
    command -v "$cmd" >/dev/null 2>&1 || { log "ERROR - Command '$cmd' not found" >&2; exit 1; }
done

docker inspect "$PLEX_CONTAINER_NAME" >/dev/null 2>&1 || {
    log "ERROR - Container '$PLEX_CONTAINER_NAME' not found" >&2
    exit 1
}

cleanup() {
    log "INFO - Received shutdown signal, exiting..."
    exit 0
}
trap cleanup TERM INT

# Extract major.minor.patch.build from version string
sanitize_version() {
    echo "$1" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true
}

# Compare two version strings (returns 0 if $1 > $2)
version_greater() {
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | tail -n1)" = "$1" ] && [ "$1" != "$2" ]
}

check_update() {
    local latest_raw current_raw latest current
    
    # Fetch latest version from Plex API
    latest_raw=$(curl -sf --max-time 10 --retry 3 --compressed \
        "https://plex.tv/api/downloads/5.json?channel=${PLEX_BRANCH}&X-Plex-Token=${PLEX_TOKEN}" \
        | jq -r '.computer.Linux.version // empty' 2>/dev/null || true)
    
    [ -z "$latest_raw" ] && { log "WARNING - Failed to fetch latest version" >&2; return 0; }
    
    # Fetch current version from Plex server
    current_raw=$(curl -sf --max-time 30 --retry 3 --compressed \
        "${PLEX_PROTOCOL}://${PLEX_IP}:${PLEX_PORT}/?X-Plex-Token=${PLEX_TOKEN}" 2>/dev/null \
        | grep -o '<MediaContainer[^>]*' | grep -o 'version="[^"]*"' | cut -d'"' -f2 || true)
    
    [ -z "$current_raw" ] && { log "WARNING - Failed to fetch current version" >&2; return 0; }
    
    latest=$(sanitize_version "$latest_raw")
    current=$(sanitize_version "$current_raw")
    
    [ -z "$latest" ] || [ -z "$current" ] && { log "ERROR - Failed to parse versions" >&2; return 0; }
    
    # Check if update is needed
    if [ "$FORCE_UPDATE" = "true" ] || version_greater "$latest" "$current"; then
        log "INFO - Update available: $current -> $latest"
        
        if docker restart "$PLEX_CONTAINER_NAME" >/dev/null 2>&1; then
            log "INFO - Plex container restarted successfully"
        else
            log "ERROR - Failed to restart container: $PLEX_CONTAINER_NAME" >&2
        fi
    else
        log "INFO - Plex is up to date (version $current)"
    fi
}

log "INFO - Starting DPAU (check interval: ${INTERVAL} minutes)"

check_update

while true; do
    sleep $((INTERVAL * 60)) &
    wait $!
    check_update
done
