#!/bin/bash
# Performance monitoring script for Hytale server container

CONTAINER_NAME="hytale-server"

echo "=== Hytale Server Performance Monitor ==="
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container ${CONTAINER_NAME} is not running"
    exit 1
fi

echo "📊 Container Stats:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker stats ${CONTAINER_NAME} --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}"
echo ""

echo "💾 Disk Usage:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker exec ${CONTAINER_NAME} du -sh /server 2>/dev/null || echo "Could not check disk usage"
echo ""

echo "🔍 Resource Limits:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker inspect ${CONTAINER_NAME} --format '{{json .HostConfig.Resources}}' | python3 -m json.tool 2>/dev/null || docker inspect ${CONTAINER_NAME} --format 'CPU: {{.HostConfig.CpuShares}} | Memory: {{.HostConfig.Memory}}'
echo ""

echo "💡 Tips:"
echo "  - CPU usage > 80%: Consider increasing CPU limits"
echo "  - Memory > 90%: Consider increasing memory limits"
echo "  - High Block I/O writes: Normal for game servers (world saves)"
echo ""
echo "To monitor continuously: watch -n 2 ./monitor.sh"
