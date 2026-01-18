#!/bin/bash
# Wrapper script to gracefully stop the Hytale server before bringing down containers

set -e

# Get script directory and navigate to compose directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_DIR="${PROJECT_ROOT}/compose"
cd "${COMPOSE_DIR}"

CONTAINER_NAME="hytale-server"

echo "Stopping Hytale server gracefully..."
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Sending /stop command to server..."
    docker exec "${CONTAINER_NAME}" hytale-cmd /stop 2>/dev/null || {
        echo "Warning: Could not send stop command (server may not be fully started)"
    }
    
    # Wait a moment for the server to process the stop command
    sleep 2
else
    echo "Container ${CONTAINER_NAME} is not running"
fi

echo "Bringing down containers..."
docker compose down --remove-orphans "$@"
