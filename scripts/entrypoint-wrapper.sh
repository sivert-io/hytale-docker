#!/bin/bash
# =============================================================================
# Entrypoint wrapper - syncs scripts from image to bind mount, then runs entrypoint
# =============================================================================

set -euo pipefail

SCRIPT_BACKUP="/opt/hytale-scripts"
SERVER_SCRIPTS="/server/scripts"

# Sync scripts from image to bind mount (if using bind mount)
sync_scripts() {
    # Check if we need to sync (scripts missing or entrypoint is different)
    if [[ ! -d "${SERVER_SCRIPTS}" ]] || \
       [[ ! -f "${SERVER_SCRIPTS}/entrypoint.sh" ]] || \
       ! cmp -s "${SCRIPT_BACKUP}/scripts/entrypoint.sh" "${SERVER_SCRIPTS}/entrypoint.sh" 2>/dev/null; then
        echo "Syncing scripts from image to data directory..."
        mkdir -p "${SERVER_SCRIPTS}"
        cp -r "${SCRIPT_BACKUP}/scripts/"* "${SERVER_SCRIPTS}/" 2>/dev/null || true
        cp "${SCRIPT_BACKUP}/hytale-cmd" /usr/local/bin/hytale-cmd 2>/dev/null || true
        cp "${SCRIPT_BACKUP}/hytale-auth" /usr/local/bin/hytale-auth 2>/dev/null || true
        chmod +x "${SERVER_SCRIPTS}/entrypoint.sh" /usr/local/bin/hytale-cmd /usr/local/bin/hytale-auth 2>/dev/null || true
        chown -R 1000:1000 "${SERVER_SCRIPTS}" 2>/dev/null || true
        echo "Scripts synced successfully"
    fi
}

# Sync scripts before running entrypoint
sync_scripts

# Run the actual entrypoint (now from synced location or original)
exec "${SERVER_SCRIPTS}/entrypoint.sh" "$@"
