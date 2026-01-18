#!/usr/bin/env bash
# =============================================================================
# Live Resource Monitoring
# Shows real-time resource usage comparison between Docker and Native
# =============================================================================

set -euo pipefail

CONTAINER_NAME="hytale-server"
INTERVAL="${INTERVAL:-2}"

# Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_RED='\033[0;31m'

while true; do
    clear
    echo -e "${C_BOLD}Hytale Server Resource Monitor${C_RESET}  (Refreshing every ${INTERVAL}s)"
    echo -e "Press Ctrl+C to exit"
    echo ""
    # Get Docker stats
    local docker_container
    docker_container=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" 2>/dev/null | head -n1)
    
    if [[ -n "$docker_container" ]]; then
        local docker_stats
        docker_stats=$(docker stats --no-stream --format '{{json .}}' "$docker_container" 2>/dev/null || echo '{}')
        local docker_cpu
        docker_cpu=$(echo "$docker_stats" | jq -r '.CPUPerc' 2>/dev/null | sed 's/%//' || echo "0")
        local docker_mem
        docker_mem=$(echo "$docker_stats" | jq -r '.MemUsage' 2>/dev/null || echo "0 MiB")
        local docker_mem_percent
        docker_mem_percent=$(echo "$docker_stats" | jq -r '.MemPerc' 2>/dev/null | sed 's/%//' || echo "0")
    else
        local docker_cpu="N/A"
        local docker_mem="N/A"
        local docker_mem_percent="N/A"
    fi
    
    # Get Native stats
    local java_pid
    java_pid=$(pgrep -f "HytaleServer.jar" | head -n1)
    
    if [[ -n "$java_pid" ]]; then
        local native_stats
        native_stats=$(ps -p "$java_pid" -o pcpu=,rss=,pmem= 2>/dev/null | tr -s ' ' || echo "")
        local native_cpu
        native_cpu=$(echo "$native_stats" | cut -d' ' -f1 || echo "0")
        local native_rss_kb
        native_rss_kb=$(echo "$native_stats" | cut -d' ' -f2 || echo "0")
        local native_mem_mb
        native_mem_mb=$(echo "scale=2; $native_rss_kb / 1024" | bc 2>/dev/null || echo "0")
        local native_mem_percent
        native_mem_percent=$(echo "$native_stats" | cut -d' ' -f3 || echo "0")
    else
        local native_cpu="N/A"
        local native_mem_mb="N/A"
        local native_mem_percent="N/A"
    fi
    
    # Print stats
    echo -e "${C_BOLD}Docker Container (${CONTAINER_NAME}):${C_RESET}"
    if [[ "$docker_cpu" != "N/A" ]]; then
        echo -e "  CPU:    ${C_CYAN}${docker_cpu}%${C_RESET}"
        echo -e "  Memory: ${C_CYAN}${docker_mem}${C_RESET} (${C_CYAN}${docker_mem_percent}%${C_RESET})"
    else
        echo -e "  ${C_YELLOW}Container not running${C_RESET}"
    fi
    echo ""
    echo -e "${C_BOLD}Native Java Process:${C_RESET}"
    if [[ "$native_cpu" != "N/A" ]]; then
        echo -e "  CPU:    ${C_CYAN}${native_cpu}%${C_RESET}"
        echo -e "  Memory: ${C_CYAN}${native_mem_mb}MB${C_RESET} (${C_CYAN}${native_mem_percent}%${C_RESET})"
    else
        echo -e "  ${C_YELLOW}Java process not running${C_RESET}"
    fi
    echo ""
    echo -e "${C_BOLD}All Java Processes:${C_RESET}"
    ps aux | grep -E "[j]ava.*HytaleServer" | awk '{printf "  PID: %s, CPU: %s%%, Mem: %s%% (%sKB RSS)\n", $2, $3, $4, $6}' || echo "  No Java processes found"
    echo ""
    echo -e "${C_BOLD}Docker Processes:${C_RESET}"
    if [[ -n "$docker_container" ]]; then
        docker top "$docker_container" 2>/dev/null | tail -n +2 | head -5 | awk '{printf "  PID: %s, CPU: %s%%, Mem: %s%%, Cmd: %s\n", $2, $3, $4, $NF}' || echo "  Could not get process info"
    else
        echo "  Container not running"
    fi
    
    sleep "$INTERVAL"
done
