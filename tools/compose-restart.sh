#!/bin/bash
# Restart Hytale server (stop then start)
# Runs compose-down.sh then compose-up.sh in order

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Restarting Hytale server..."
echo ""

# First stop the server
echo "=== Stopping server ==="
"${SCRIPT_DIR}/compose-down.sh"
echo ""

# Then start it (pass through all arguments)
echo "=== Starting server ==="
"${SCRIPT_DIR}/compose-up.sh" "$@"
