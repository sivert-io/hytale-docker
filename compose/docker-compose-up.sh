#!/bin/bash
# Start Hytale server with optional rebuild/recreate options

set -e

REBUILD=false
RECREATE=false
NO_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild)
            REBUILD=true
            shift
            ;;
        --recreate)
            RECREATE=true
            shift
            ;;
        --no-build)
            NO_BUILD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--rebuild] [--recreate] [--no-build]"
            echo ""
            echo "Options:"
            echo "  --rebuild    Force rebuild the Docker image (no cache)"
            echo "  --recreate   Force recreate containers (picks up new env vars)"
            echo "  --no-build   Skip building (use existing image)"
            exit 1
            ;;
    esac
done

# Check for existing container and remove if needed
CONTAINER_NAME="hytale-server"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Removing existing container ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
fi

# Build image if requested (or if not skipping build)
if [[ "$REBUILD" == "true" ]]; then
    echo "Rebuilding Docker image (no cache)..."
    docker compose build --no-cache
    RECREATE=true
elif [[ "$NO_BUILD" != "true" ]]; then
    echo "Building Docker image (if needed)..."
    docker compose build
fi

# Start with or without recreate
BUILD_FLAG=""
if [[ "$NO_BUILD" == "true" ]]; then
    BUILD_FLAG="--no-build"
fi

if [[ "$RECREATE" == "true" ]]; then
    echo "Starting server with force recreate..."
    docker compose up -d --force-recreate --remove-orphans $BUILD_FLAG
else
    echo "Starting server..."
    docker compose up -d --remove-orphans $BUILD_FLAG
fi

echo ""
echo "Server started! Watch logs with: docker compose logs -f"
