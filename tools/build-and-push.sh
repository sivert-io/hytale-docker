#!/bin/bash
# Build and push Hytale Docker image for multiple architectures

set -e

# Default values
IMAGE_NAME="${DOCKER_IMAGE:-sivert-io/hytale-docker}"
TAG="${DOCKER_TAG:-latest}"
PLATFORMS="${DOCKER_PLATFORMS:-linux/amd64,linux/arm64}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Hytale Docker Multi-Arch Build ===${NC}"
echo ""
echo "Image: ${IMAGE_NAME}:${TAG}"
echo "Platforms: ${PLATFORMS}"
echo ""

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if docker buildx is available
if ! docker buildx version &> /dev/null; then
    echo -e "${RED}Error: Docker Buildx is not available${NC}"
    echo "Buildx is required for multi-architecture builds"
    exit 1
fi

# Check if logged in to Docker Hub
if ! docker info | grep -q "Username"; then
    echo -e "${YELLOW}Warning: Not logged in to Docker Hub${NC}"
    echo "You may need to run: docker login"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create and use buildx builder if it doesn't exist
BUILDER_NAME="hytale-multiarch"

if ! docker buildx ls | grep -q "${BUILDER_NAME}"; then
    echo -e "${YELLOW}Creating buildx builder: ${BUILDER_NAME}${NC}"
    docker buildx create --name "${BUILDER_NAME}" --use --bootstrap
else
    echo -e "${GREEN}Using existing buildx builder: ${BUILDER_NAME}${NC}"
    docker buildx use "${BUILDER_NAME}"
fi

# Build and push multi-arch image
echo ""
echo -e "${GREEN}Building and pushing multi-architecture image...${NC}"
echo ""

docker buildx build \
    --platform "${PLATFORMS}" \
    --tag "${IMAGE_NAME}:${TAG}" \
    --tag "${IMAGE_NAME}:latest" \
    --push \
    --file Dockerfile \
    --progress=plain \
    .

echo ""
echo -e "${GREEN}✓ Successfully built and pushed ${IMAGE_NAME}:${TAG}${NC}"
echo -e "${GREEN}  Platforms: ${PLATFORMS}${NC}"
echo ""
echo "To pull the image:"
echo "  docker pull ${IMAGE_NAME}:${TAG}"
