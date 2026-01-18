#!/usr/bin/env bash
# =============================================================================
# Automated Benchmark Script
# Runs Docker and Native sequentially, records metrics, and compares results
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPARE_SCRIPT="${SCRIPT_DIR}/compare-resources.sh"
COMPOSE_UP="${SCRIPT_DIR}/compose-up.sh"
COMPOSE_DOWN="${SCRIPT_DIR}/compose-down.sh"
RUN_NATIVE="${SCRIPT_DIR}/run-native.sh"

DOCKER_RECORD_DURATION="${DOCKER_DURATION:-300}"  # 5 minutes default
NATIVE_RECORD_DURATION="${NATIVE_DURATION:-300}"  # 5 minutes default
INTERVAL="${INTERVAL:-1}"  # seconds between samples (1 second for better statistics)
CONTAINER_NAME="hytale-server"

# =============================================================================
# Colors
# =============================================================================
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_RED='\033[0;31m'

# =============================================================================
# Helper functions
# =============================================================================
log_info() {
    echo -e "${C_CYAN}[INFO]${C_RESET} $1" >&2
}

log_success() {
    echo -e "${C_GREEN}[✓]${C_RESET} $1" >&2
}

log_warn() {
    echo -e "${C_YELLOW}[WARN]${C_RESET} $1" >&2
}

log_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2
}

print_header() {
    echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════${C_RESET}" >&2
    echo -e "${C_BOLD}  $1${C_RESET}" >&2
    echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════${C_RESET}" >&2
}

print_section() {
    echo "" >&2
    echo -e "${C_BOLD}${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}" >&2
    echo -e "${C_BOLD}  $1${C_RESET}" >&2
    echo -e "${C_BOLD}${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}" >&2
    echo "" >&2
}

# =============================================================================
# Check if Docker container is running
# =============================================================================
is_docker_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null || return 1
}

# =============================================================================
# Check if native Java process is running
# =============================================================================
is_native_running() {
    pgrep -f "HytaleServer.jar" >/dev/null 2>&1 || return 1
}

# =============================================================================
# Wait for Docker container to be ready
# =============================================================================
wait_for_docker() {
    log_info "Waiting for Docker container to start..."
    local max_wait=60
    local waited=0
    
    while ! is_docker_running && [[ $waited -lt $max_wait ]]; do
        sleep 2
        waited=$((waited + 2))
        printf "." >&2
    done
    
    echo "" >&2
    
    if ! is_docker_running; then
        log_error "Docker container failed to start within $max_wait seconds"
        return 1
    fi
    
    # Wait for server to boot (check logs for boot message)
    log_info "Waiting for server to boot (checking for 'Hytale Server Booted! [Multiplayer]')..."
    local boot_wait=180  # Up to 3 minutes for server to boot
    local boot_waited=0
    
    while [[ $boot_waited -lt $boot_wait ]]; do
        if docker logs "${CONTAINER_NAME}" 2>&1 | grep -q "Hytale Server Booted! \[Multiplayer\]"; then
            log_success "Server booted and ready!"
            return 0
        fi
        sleep 2
        boot_waited=$((boot_waited + 2))
        if [[ $((boot_waited % 10)) -eq 0 ]]; then
            printf "." >&2
        fi
    done
    
    echo "" >&2
    log_warn "Server boot message not found in logs, but continuing anyway..."
    log_success "Docker container is ready"
}

# =============================================================================
# Wait for native server to be ready
# =============================================================================
wait_for_native() {
    log_info "Waiting for native server to start..."
    local max_wait=60
    local waited=0
    
    while ! is_native_running && [[ $waited -lt $max_wait ]]; do
        sleep 2
        waited=$((waited + 2))
        printf "." >&2
    done
    
    echo "" >&2
    
    if ! is_native_running; then
        log_error "Native server failed to start within $max_wait seconds"
        return 1
    fi
    
    # Wait for server to boot (check logs for boot message)
    log_info "Waiting for server to boot (checking for 'Hytale Server Booted! [Multiplayer]')..."
    local boot_wait=180  # Up to 3 minutes for server to boot
    local boot_waited=0
    local logs_dir="${PROJECT_ROOT}/data/logs"
    local native_log="/tmp/hytale-native.log"
    
    while [[ $boot_waited -lt $boot_wait ]]; do
        # Check the most recent log file in logs directory
        local latest_log
        latest_log=$(find "$logs_dir" -name "*.log" -type f ! -name "*.lck" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
        
        if [[ -n "$latest_log" ]] && [[ -f "$latest_log" ]] && grep -q "Hytale Server Booted! \[Multiplayer\]" "$latest_log" 2>/dev/null; then
            log_success "Server booted and ready!"
            return 0
        fi
        # Also check the native output log (stdout/stderr from run-native.sh)
        if [[ -f "$native_log" ]] && grep -q "Hytale Server Booted! \[Multiplayer\]" "$native_log" 2>/dev/null; then
            log_success "Server booted and ready!"
            return 0
        fi
        sleep 2
        boot_waited=$((boot_waited + 2))
        if [[ $((boot_waited % 10)) -eq 0 ]]; then
            printf "." >&2
        fi
    done
    
    echo "" >&2
    log_warn "Server boot message not found in logs, but continuing anyway..."
    log_success "Native server is ready"
}

# =============================================================================
# Stop native server using /quit command
# =============================================================================
stop_native_server() {
    log_info "Stopping native server gracefully..."
    
    local java_pid
    java_pid=$(pgrep -f "HytaleServer.jar" | head -n1)
    
    if [[ -z "$java_pid" ]]; then
        log_warn "Native server process not found"
        return 0
    fi
    
    # Try to send /quit command if we have access to stdin
    # Since the native script uses exec, we can't send commands directly
    # So we'll just kill it gracefully
    log_info "Sending SIGTERM to native server..."
    kill -TERM "$java_pid" 2>/dev/null || true
    
    # Wait for process to exit
    local max_wait=30
    local waited=0
    
    while kill -0 "$java_pid" 2>/dev/null && [[ $waited -lt $max_wait ]]; do
        sleep 1
        waited=$((waited + 1))
    done
    
    # Force kill if still running
    if kill -0 "$java_pid" 2>/dev/null; then
        log_warn "Server didn't stop gracefully, forcing shutdown..."
        kill -KILL "$java_pid" 2>/dev/null || true
    fi
    
    log_success "Native server stopped"
}

# =============================================================================
# Run Docker benchmark
# =============================================================================
run_docker_benchmark() {
    print_section "Phase 1: Docker Benchmark"
    
    log_info "Starting Docker server..."
    if ! "$COMPOSE_UP" >/dev/null 2>&1; then
        log_error "Failed to start Docker server"
        return 1
    fi
    
    wait_for_docker
    
    log_info "Recording Docker metrics for ${DOCKER_RECORD_DURATION} seconds..."
    log_info "This will take approximately $((DOCKER_RECORD_DURATION / 60)) minutes"
    
    local docker_output
    docker_output=$(MODE=docker DURATION="$DOCKER_RECORD_DURATION" INTERVAL="$INTERVAL" "$COMPARE_SCRIPT" record 2>&1)
    local docker_csv_relative
    docker_csv_relative=$(echo "$docker_output" | grep -o "metrics/docker_[0-9_]*\.csv" | head -n1 || echo "")
    
    if [[ -n "$docker_csv_relative" ]]; then
        # Convert relative path to absolute if needed
        if [[ "$docker_csv_relative" == metrics/* ]]; then
            DOCKER_CSV="${PROJECT_ROOT}/${docker_csv_relative}"
        else
            DOCKER_CSV="$docker_csv_relative"
        fi
    else
        # Fallback: find latest docker CSV
        DOCKER_CSV=$(find "${PROJECT_ROOT}/metrics" -name "docker_*.csv" -type f | sort -r | head -n1 || echo "")
    fi
    
    # Ensure absolute path for Docker CSV
    if [[ -n "$DOCKER_CSV" ]] && [[ "$DOCKER_CSV" == metrics/* ]]; then
        DOCKER_CSV="${PROJECT_ROOT}/${DOCKER_CSV}"
    fi
    
    log_success "Docker recording complete: $DOCKER_CSV"
    
    log_info "Stopping Docker server..."
    if ! "$COMPOSE_DOWN" >/dev/null 2>&1; then
        log_warn "Failed to stop Docker server gracefully"
    fi
    
    # Wait for container to fully stop
    sleep 5
    
    log_success "Docker benchmark complete"
}

# =============================================================================
# Run Native benchmark
# =============================================================================
run_native_benchmark() {
    print_section "Phase 2: Native Benchmark"
    
    log_info "Starting native server..."
    log_warn "Starting native server in background. It will run until we stop it."
    
    # Start native server in background
    "$RUN_NATIVE" >/tmp/hytale-native.log 2>&1 &
    NATIVE_PID=$!
    
    wait_for_native
    
    log_info "Recording native metrics for ${NATIVE_RECORD_DURATION} seconds..."
    log_info "This will take approximately $((NATIVE_RECORD_DURATION / 60)) minutes"
    
    local native_output
    native_output=$(MODE=native DURATION="$NATIVE_RECORD_DURATION" INTERVAL="$INTERVAL" "$COMPARE_SCRIPT" record 2>&1)
    local native_csv_relative
    native_csv_relative=$(echo "$native_output" | grep -o "metrics/native_[0-9_]*\.csv" | head -n1 || echo "")
    
    if [[ -n "$native_csv_relative" ]]; then
        # Convert relative path to absolute if needed
        if [[ "$native_csv_relative" == metrics/* ]]; then
            NATIVE_CSV="${PROJECT_ROOT}/${native_csv_relative}"
        else
            NATIVE_CSV="$native_csv_relative"
        fi
    else
        # Fallback: find latest native CSV
        NATIVE_CSV=$(find "${PROJECT_ROOT}/metrics" -name "native_*.csv" -type f | sort -r | head -n1 || echo "")
    fi
    
    # Ensure absolute path for Native CSV
    if [[ -n "$NATIVE_CSV" ]] && [[ "$NATIVE_CSV" == metrics/* ]]; then
        NATIVE_CSV="${PROJECT_ROOT}/${NATIVE_CSV}"
    fi
    
    log_success "Native recording complete: $NATIVE_CSV"
    
    log_info "Stopping native server..."
    stop_native_server
    
    log_success "Native benchmark complete"
}

# =============================================================================
# Show detailed comparison and winner
# =============================================================================
show_comparison() {
    print_section "Phase 3: Results & Comparison"
    
    if [[ -z "${DOCKER_CSV:-}" ]]; then
        log_error "Docker CSV file path not set"
        return 1
    fi
    
    if [[ -z "${NATIVE_CSV:-}" ]]; then
        log_error "Native CSV file path not set"
        return 1
    fi
    
    # Use the paths directly (already absolute)
    local docker_file="${DOCKER_CSV}"
    local native_file="${NATIVE_CSV}"
    
    if [[ ! -f "$docker_file" ]]; then
        log_error "Docker CSV file not found: $docker_file"
        return 1
    fi
    
    if [[ ! -f "$native_file" ]]; then
        log_error "Native CSV file not found: $native_file"
        return 1
    fi
    
    # Use the statistical comparison function from compare-resources.sh
    # Call it and capture output for winner calculation
    local comparison_output
    comparison_output=$("$COMPARE_SCRIPT" compare "$docker_file" "$native_file" 2>&1)
    
    # Extract statistical values from the output for winner calculation
    # We'll use the existing calculation but with better stats from compare-resources.sh
    # For now, calculate here but we could parse from comparison_output if needed
    
    # Calculate statistical metrics (mean, stddev, min, max, count)
    calc_stats() {
        local file="$1"
        local col="$2"
        tail -n +2 "$file" | cut -d',' -f"$col" | awk '
            {
                sum += $1
                sum_sq += $1 * $1
                count++
                if (NR == 1 || $1 < min) min = $1
                if (NR == 1 || $1 > max) max = $1
            }
            END {
                if (count > 0) {
                    mean = sum / count
                    variance = (sum_sq / count) - (mean * mean)
                    stddev = sqrt(variance > 0 ? variance : 0)
                    printf "%.2f %.2f %.2f %.2f %d", mean, stddev, min, max, count
                } else {
                    printf "0 0 0 0 0"
                }
            }
        '
    }
    
    local docker_cpu_stats docker_mem_stats
    docker_cpu_stats=$(calc_stats "$docker_file" 2)
    docker_mem_stats=$(calc_stats "$docker_file" 3)
    
    local docker_avg_cpu docker_stddev_cpu docker_min_cpu docker_max_cpu docker_count
    docker_avg_cpu=$(echo "$docker_cpu_stats" | cut -d' ' -f1)
    docker_stddev_cpu=$(echo "$docker_cpu_stats" | cut -d' ' -f2)
    docker_min_cpu=$(echo "$docker_cpu_stats" | cut -d' ' -f3)
    docker_max_cpu=$(echo "$docker_cpu_stats" | cut -d' ' -f4)
    docker_count=$(echo "$docker_cpu_stats" | cut -d' ' -f5)
    
    local docker_avg_mem docker_stddev_mem docker_min_mem docker_max_mem
    docker_avg_mem=$(echo "$docker_mem_stats" | cut -d' ' -f1)
    docker_stddev_mem=$(echo "$docker_mem_stats" | cut -d' ' -f2)
    docker_min_mem=$(echo "$docker_mem_stats" | cut -d' ' -f3)
    docker_max_mem=$(echo "$docker_mem_stats" | cut -d' ' -f4)
    
    local native_cpu_stats native_mem_stats
    native_cpu_stats=$(calc_stats "$native_file" 2)
    native_mem_stats=$(calc_stats "$native_file" 4)
    
    local native_avg_cpu native_stddev_cpu native_min_cpu native_max_cpu native_count
    native_avg_cpu=$(echo "$native_cpu_stats" | cut -d' ' -f1)
    native_stddev_cpu=$(echo "$native_cpu_stats" | cut -d' ' -f2)
    native_min_cpu=$(echo "$native_cpu_stats" | cut -d' ' -f3)
    native_max_cpu=$(echo "$native_cpu_stats" | cut -d' ' -f4)
    native_count=$(echo "$native_cpu_stats" | cut -d' ' -f5)
    
    local native_avg_mem native_stddev_mem native_min_mem native_max_mem
    native_avg_mem=$(echo "$native_mem_stats" | cut -d' ' -f1)
    native_stddev_mem=$(echo "$native_mem_stats" | cut -d' ' -f2)
    native_min_mem=$(echo "$native_mem_stats" | cut -d' ' -f3)
    native_max_mem=$(echo "$native_mem_stats" | cut -d' ' -f4)
    
    # Calculate differences
    local cpu_diff mem_diff
    if command -v bc >/dev/null 2>&1; then
        cpu_diff=$(echo "scale=2; $docker_avg_cpu - $native_avg_cpu" | bc)
        mem_diff=$(echo "scale=2; $docker_avg_mem - $native_avg_mem" | bc)
    else
        # Fallback if bc not available
        cpu_diff=$(awk "BEGIN {printf \"%.2f\", $docker_avg_cpu - $native_avg_cpu}")
        mem_diff=$(awk "BEGIN {printf \"%.2f\", $docker_avg_mem - $native_avg_mem}")
    fi
    
    # Display results
    echo ""
    echo -e "${C_BOLD}═══════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BOLD}                    BENCHMARK RESULTS${C_RESET}"
    echo -e "${C_BOLD}═══════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    
    echo -e "${C_BOLD}Sample Statistics:${C_RESET}"
    printf "  ${C_CYAN}Docker:${C_RESET}  %d samples (recorded every ${INTERVAL} second(s))\n" "$docker_count"
    printf "  ${C_CYAN}Native:${C_RESET}  %d samples (recorded every ${INTERVAL} second(s))\n" "$native_count"
    echo ""
    
    echo -e "${C_BOLD}CPU Usage Statistics (Mean ± Std Dev):${C_RESET}"
    printf "  ${C_CYAN}Docker:${C_RESET}  %.2f%% ± %.2f%%  (range: %.2f%% - %.2f%%)\n" "$docker_avg_cpu" "$docker_stddev_cpu" "$docker_min_cpu" "$docker_max_cpu"
    printf "  ${C_CYAN}Native:${C_RESET}  %.2f%% ± %.2f%%  (range: %.2f%% - %.2f%%)\n" "$native_avg_cpu" "$native_stddev_cpu" "$native_min_cpu" "$native_max_cpu"
    echo ""
    
    echo -e "${C_BOLD}Memory Usage Statistics (Mean ± Std Dev):${C_RESET}"
    printf "  ${C_CYAN}Docker:${C_RESET}  %.2fMB ± %.2fMB  (range: %.2fMB - %.2fMB)\n" "$docker_avg_mem" "$docker_stddev_mem" "$docker_min_mem" "$docker_max_mem"
    printf "  ${C_CYAN}Native:${C_RESET}  %.2fMB ± %.2fMB  (range: %.2fMB - %.2fMB)\n" "$native_avg_mem" "$native_stddev_mem" "$native_min_mem" "$native_max_mem"
    echo ""
    
    echo -e "${C_BOLD}Difference (Docker - Native):${C_RESET}"
    if (( $(echo "$cpu_diff > 0" | bc -l 2>/dev/null || echo 0) )); then
        printf "  CPU:    ${C_RED}+%.2f%%${C_RESET} (Docker uses more)\n" "$cpu_diff"
    else
        printf "  CPU:    ${C_GREEN}%.2f%%${C_RESET} (Native uses more)\n" "$cpu_diff"
    fi
    
    if (( $(echo "$mem_diff > 0" | bc -l 2>/dev/null || echo 0) )); then
        printf "  Memory: ${C_RED}+%.2fMB${C_RESET} (Docker uses more)\n" "$mem_diff"
    else
        printf "  Memory: ${C_GREEN}%.2fMB${C_RESET} (Native uses more)\n" "$mem_diff"
    fi
    echo ""
    
    # Determine winner
    local winner=""
    local cpu_winner mem_winner
    
    if (( $(echo "$docker_avg_cpu < $native_avg_cpu" | bc -l 2>/dev/null || echo 0) )); then
        cpu_winner="Docker"
    elif (( $(echo "$docker_avg_cpu > $native_avg_cpu" | bc -l 2>/dev/null || echo 0) )); then
        cpu_winner="Native"
    else
        cpu_winner="Tie"
    fi
    
    if (( $(echo "$docker_avg_mem < $native_avg_mem" | bc -l 2>/dev/null || echo 0) )); then
        mem_winner="Docker"
    elif (( $(echo "$docker_avg_mem > $native_avg_mem" | bc -l 2>/dev/null || echo 0) )); then
        mem_winner="Native"
    else
        mem_winner="Tie"
    fi
    
    # Overall winner (lower CPU + Memory is better)
    local docker_score native_score
    docker_score=$(awk "BEGIN {printf \"%.2f\", $docker_avg_cpu + ($docker_avg_mem / 100)}" 2>/dev/null || echo "999")
    native_score=$(awk "BEGIN {printf \"%.2f\", $native_avg_cpu + ($native_avg_mem / 100)}" 2>/dev/null || echo "999")
    
    if (( $(echo "$docker_score < $native_score" | bc -l 2>/dev/null || echo 0) )); then
        winner="Docker"
    elif (( $(echo "$native_score < $docker_score" | bc -l 2>/dev/null || echo 0) )); then
        winner="Native"
    else
        winner="Tie"
    fi
    
    echo -e "${C_BOLD}═══════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BOLD}                     PERFORMANCE WINNER${C_RESET}"
    echo -e "${C_BOLD}═══════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    echo -e "  CPU Performance:    ${C_CYAN}${cpu_winner}${C_RESET}"
    echo -e "  Memory Efficiency:  ${C_CYAN}${mem_winner}${C_RESET}"
    echo ""
    
    if [[ "$winner" == "Tie" ]]; then
        echo -e "  ${C_BOLD}Overall Winner:${C_RESET}  ${C_YELLOW}Tie - Both perform similarly${C_RESET}"
    else
        echo -e "  ${C_BOLD}Overall Winner:${C_RESET}  ${C_GREEN}${winner}${C_RESET}"
        if [[ "$winner" == "Docker" ]]; then
            echo -e "  ${C_GREEN}✓ Docker uses less resources overall${C_RESET}"
        else
            echo -e "  ${C_GREEN}✓ Native uses less resources overall${C_RESET}"
        fi
    fi
    
    echo ""
    echo -e "${C_BOLD}Files saved:${C_RESET}"
    echo -e "  Docker: $docker_file"
    echo -e "  Native: $native_file"
    echo ""
}

# =============================================================================
# Cleanup on exit
# =============================================================================
cleanup() {
    log_info "Cleaning up..."
    
    # Stop native if running
    if is_native_running; then
        stop_native_server
    fi
    
    # Stop docker if running
    if is_docker_running; then
        "$COMPOSE_DOWN" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT INT TERM

# =============================================================================
# Main
# =============================================================================
main() {
    print_header "Automated Hytale Server Benchmark"
    
    log_info "This will run Docker and Native servers sequentially"
    log_info "Each will run for approximately $((DOCKER_RECORD_DURATION / 60)) minutes"
    log_info "Total time: ~$(((DOCKER_RECORD_DURATION + NATIVE_RECORD_DURATION) / 60)) minutes"
    echo ""
    
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
    
    # Check dependencies
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required but not installed. Install with: sudo apt-get install jq"
        exit 1
    fi
    
    # Make sure metrics directory exists and clean old files
    mkdir -p "${PROJECT_ROOT}/metrics"
    log_info "Cleaning old metrics files..."
    rm -f "${PROJECT_ROOT}/metrics"/*.csv 2>/dev/null || true
    log_success "Old metrics cleaned"
    
    # Run benchmarks
    run_docker_benchmark || {
        log_error "Docker benchmark failed"
        exit 1
    }
    
    run_native_benchmark || {
        log_error "Native benchmark failed"
        exit 1
    }
    
    # Show results
    show_comparison || {
        log_error "Failed to show comparison"
        exit 1
    }
    
    log_success "Benchmark complete!"
}

main "$@"
