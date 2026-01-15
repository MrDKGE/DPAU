#!/bin/sh
set -euo pipefail

# Configuration
PLEX_TOKEN="${PLEX_TOKEN:?PLEX_TOKEN is required}"
PLEX_BRANCH="${PLEX_BRANCH:-public}"
PLEX_PROTOCOL="${PLEX_PROTOCOL:-http}"
PLEX_IP="${PLEX_IP:-127.0.0.1}"
PLEX_PORT="${PLEX_PORT:-32400}"
PLEX_CONTAINER_NAME="${PLEX_CONTAINER_NAME:-plex}"
FORCE_UPDATE="${FORCE_UPDATE:-false}"
INTERVAL="${INTERVAL:-360}"

# Validate interval
if [ "$INTERVAL" -lt 5 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Interval must be at least 5 minutes" >&2
    exit 1
fi

# Check required commands
for cmd in curl jq docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Required command '$cmd' not found" >&2
        echo "Install it with: apt install $cmd (Debian/Ubuntu) or brew install $cmd (macOS)" >&2
        exit 1
    fi
done

# Verify Plex container exists
if ! docker inspect "$PLEX_CONTAINER_NAME" >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Container '$PLEX_CONTAINER_NAME' not found" >&2
    echo "Make sure the Plex container is running and the name matches PLEX_CONTAINER_NAME" >&2
    exit 1
fi

# Graceful shutdown handler
cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - Received shutdown signal, exiting..."
    exit 0
}
trap cleanup TERM INT

get_latest_version() {
    curl -sf --max-time 10 --retry 3 --retry-delay 2 --retry-max-time 30 \
        --compressed \
        "https://plex.tv/api/downloads/5.json?channel=${PLEX_BRANCH}" \
        | jq -r '.computer.Linux.version // empty' 2>/dev/null || true
}

get_current_version() {
    curl -sf --max-time 30 --retry 3 --retry-delay 2 --retry-max-time 60 \
        --compressed \
        "${PLEX_PROTOCOL}://${PLEX_IP}:${PLEX_PORT}/?X-Plex-Token=${PLEX_TOKEN}" 2>/dev/null \
        | tr ' ' '\n' | grep '^version=' | cut -d'"' -f2 || true
}

sanitize_version() {
    echo "$1" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true
}

version_greater() {
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | tail -n1)" = "$1" ] && [ "$1" != "$2" ]
}

restart_container() {
    if docker restart "$PLEX_CONTAINER_NAME" >/dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - Plex container restarted successfully"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Failed to restart container: $PLEX_CONTAINER_NAME" >&2
        return 1
    fi
}

check_update() {
    local latest_raw current_raw latest current
    
    latest_raw=$(get_latest_version)
    current_raw=$(get_current_version)
    
    if [ -z "$latest_raw" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING - Failed to fetch latest version from plex.tv" >&2
        return 0
    fi
    
    if [ -z "$current_raw" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING - Failed to fetch current version from Plex server" >&2
        return 0
    fi
    
    latest=$(sanitize_version "$latest_raw")
    current=$(sanitize_version "$current_raw")
    
    if [ -z "$latest" ] || [ -z "$current" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Failed to parse versions" >&2
        return 0
    fi
    
    if [ "$FORCE_UPDATE" = "true" ] || version_greater "$latest" "$current"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - Update available: $current -> $latest"
        restart_container
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - Plex is up to date (version $current)"
    fi
}

echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO - Starting DPAU (check interval: ${INTERVAL} minutes)"

check_update

while true; do
    sleep $((INTERVAL * 60)) &
    wait $!
    check_update
done
