#!/usr/bin/env bash
# =============================================================================
# Resource Usage Comparison Tool
# Compares resource usage between native Java and Docker container
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../metrics"
CONTAINER_NAME="hytale-server"
INTERVAL="${INTERVAL:-5}"  # seconds between samples
DURATION="${DURATION:-60}"  # total duration in seconds

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

# =============================================================================
# Check dependencies
# =============================================================================
check_dependencies() {
    local missing=()
    
    for cmd in docker ps jq bc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        log_info "Install missing packages: sudo apt-get install ${missing[*]}"
        exit 1
    fi
}

# =============================================================================
# Get Docker container metrics
# =============================================================================
get_docker_metrics() {
    local container_id
    container_id=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | head -n1)
    
    if [[ -z "$container_id" ]]; then
        echo "0,0,0,0,0,0"
        return
    fi
    
    # Get container stats (JSON format)
    docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}" "$container_id" 2>/dev/null | \
        sed 's/%//g' | \
        sed 's/MiB / MiB,/g' | \
        sed 's/ /_/g' || echo "0,0,0,0,0,0"
}

# =============================================================================
# Get Docker container CPU usage using cgroup (faster than docker stats)
# =============================================================================
get_docker_cpu() {
    local container_id
    container_id=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | head -n1)
    
    if [[ -z "$container_id" ]]; then
        echo "0"
        return
    fi
    
    # Try cgroup v2 first (newer systems)
    local cgroup_path
    cgroup_path="/sys/fs/cgroup/system.slice/docker-${container_id}.scope/cpu.stat"
    
    if [[ ! -f "$cgroup_path" ]]; then
        # Try cgroup v1 (older systems)
        cgroup_path="/sys/fs/cgroup/cpu/docker/${container_id}/cpu.stat"
    fi
    
    if [[ -f "$cgroup_path" ]]; then
        # Read CPU usage from cgroup (in microseconds)
        local cpu_usage
        cpu_usage=$(grep "^usage_usec" "$cgroup_path" 2>/dev/null | awk '{print $2}' || echo "0")
        
        # Get previous reading (store in temp file)
        local temp_file="/tmp/docker_cpu_${container_id}"
        local prev_usage prev_time
        if [[ -f "$temp_file" ]]; then
            prev_usage=$(cut -d' ' -f1 "$temp_file" 2>/dev/null || echo "0")
            prev_time=$(cut -d' ' -f2 "$temp_file" 2>/dev/null || echo "0")
        else
            prev_usage="0"
            prev_time=$(date +%s%N | cut -b1-13)  # milliseconds
        fi
        
        # Calculate CPU percentage
        local current_time elapsed_usec cpu_percent
        current_time=$(date +%s%N | cut -b1-13)  # milliseconds
        elapsed_usec=$(( (current_time - prev_time) * 1000 ))  # convert to microseconds
        
        if [[ $elapsed_usec -gt 0 ]] && [[ $prev_usage -gt 0 ]]; then
            local cpu_delta
            cpu_delta=$((cpu_usage - prev_usage))
            # CPU percentage = (cpu_delta / elapsed_usec) * 100
            cpu_percent=$(awk "BEGIN {printf \"%.2f\", ($cpu_delta / $elapsed_usec) * 100}" 2>/dev/null || echo "0")
        else
            cpu_percent="0"
        fi
        
        # Save current reading
        echo "$cpu_usage $current_time" > "$temp_file"
        echo "$cpu_percent"
    else
        # Fallback to docker stats if cgroup not available (slower)
        docker stats --no-stream --format '{{json .}}' "$container_id" 2>/dev/null | \
            jq -r '.CPUPerc' | \
            sed 's/%//' || echo "0"
    fi
}

# =============================================================================
# Get Docker memory usage using cgroup (faster than docker stats)
# =============================================================================
get_docker_memory() {
    local container_id
    container_id=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | head -n1)
    
    if [[ -z "$container_id" ]]; then
        echo "0,0"
        return
    fi
    
    # Use cgroup stats directly (much faster than docker stats)
    # Try cgroup v2 first
    local cgroup_path
    cgroup_path="/sys/fs/cgroup/system.slice/docker-${container_id}.scope/memory.current"
    
    if [[ ! -f "$cgroup_path" ]]; then
        # Try cgroup v1
        cgroup_path="/sys/fs/cgroup/memory/docker/${container_id}/memory.usage_in_bytes"
    fi
    
        if [[ -f "$cgroup_path" ]]; then
        # Read memory usage from cgroup (in bytes for v1, already in bytes for v2)
        local mem_bytes
        mem_bytes=$(cat "$cgroup_path" 2>/dev/null || echo "0")
        # cgroup v2 uses "max" for unlimited, handle that
        if [[ "$mem_bytes" == "max" ]]; then
            mem_bytes="0"
        fi
        local mem_mb
        mem_mb=$(awk "BEGIN {printf \"%.2f\", $mem_bytes / 1024 / 1024}" 2>/dev/null || echo "0")
        
        # Get memory limit to calculate percentage
        local mem_limit_path
        mem_limit_path="/sys/fs/cgroup/system.slice/docker-${container_id}.scope/memory.max"
        
        if [[ ! -f "$mem_limit_path" ]]; then
            mem_limit_path="/sys/fs/cgroup/memory/docker/${container_id}/memory.limit_in_bytes"
        fi
        local mem_limit mem_percent
        if [[ -f "$mem_limit_path" ]]; then
            local mem_limit_str
            mem_limit_str=$(cat "$mem_limit_path" 2>/dev/null || echo "max")
            # cgroup v2 uses "max" for unlimited
            if [[ "$mem_limit_str" == "max" ]]; then
                mem_limit="0"
            else
                mem_limit="$mem_limit_str"
            fi
            if [[ $mem_limit -gt 0 ]] && [[ $mem_limit -lt 18446744073709551615 ]]; then  # Not unlimited
                mem_percent=$(awk "BEGIN {printf \"%.2f\", ($mem_bytes / $mem_limit) * 100}" 2>/dev/null || echo "0")
            else
                # Unlimited or very large, use system memory
                local sys_mem_total
                sys_mem_total=$(free -b | awk 'NR==2{print $2}')
                mem_percent=$(awk "BEGIN {printf \"%.2f\", ($mem_bytes / $sys_mem_total) * 100}" 2>/dev/null || echo "0")
            fi
        else
            mem_percent="0"
        fi
        
        echo "${mem_mb},${mem_percent}"
    else
        # Fallback to docker stats if cgroup not available
        local stats_json
        stats_json=$(docker stats --no-stream --format '{{json .}}' "$container_id" 2>/dev/null || echo "{}")
        local mem_usage_str mem_percent
        mem_usage_str=$(echo "$stats_json" | jq -r '.MemUsage' || echo "0")
        mem_percent=$(echo "$stats_json" | jq -r '.MemPerc' | sed 's/%//' || echo "0")
        
        # Extract memory value and convert to MB
        local mem_value mem_unit mem_mb
        mem_value=$(echo "$mem_usage_str" | awk '{print $1}' | sed -E 's/([0-9.]+)([A-Za-z]+)/\1 \2/' | awk '{print $1}')
        mem_unit=$(echo "$mem_usage_str" | awk '{print $1}' | sed -E 's/([0-9.]+)([A-Za-z]+)/\1 \2/' | awk '{print $2}')
        
        if [[ "$mem_unit" == "GiB" ]] || [[ "$mem_unit" == "GB" ]]; then
            mem_mb=$(awk "BEGIN {printf \"%.2f\", $mem_value * 1024}" 2>/dev/null || echo "0")
        elif [[ "$mem_unit" == "MiB" ]] || [[ "$mem_unit" == "MB" ]]; then
            mem_mb="$mem_value"
        elif [[ "$mem_unit" == "KiB" ]] || [[ "$mem_unit" == "KB" ]]; then
            mem_mb=$(awk "BEGIN {printf \"%.2f\", $mem_value / 1024}" 2>/dev/null || echo "0")
        else
            mem_mb="0"
        fi
        
        echo "${mem_mb},${mem_percent}"
    fi
}

# =============================================================================
# Get system-wide metrics (entire VM)
# =============================================================================
get_system_metrics() {
    # Total CPU usage (all cores) - using top for accuracy
    local cpu_total
    cpu_total=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")
    
    # Total memory usage
    local mem_total mem_used mem_percent
    mem_total=$(free -m | awk 'NR==2{print $2}' 2>/dev/null || echo "0")
    mem_used=$(free -m | awk 'NR==2{print $3}' 2>/dev/null || echo "0")
    mem_percent=$(awk "BEGIN {if ($mem_total > 0) printf \"%.2f\", ($mem_used / $mem_total) * 100; else print \"0\"}" 2>/dev/null || echo "0")
    
    echo "${cpu_total},${mem_used},${mem_percent}"
}

# =============================================================================
# Get native Java process CPU usage
# =============================================================================
get_native_cpu() {
    local java_pid
    java_pid=$(pgrep -f "HytaleServer.jar" | head -n1)
    
    if [[ -z "$java_pid" ]]; then
        echo "0"
        return
    fi
    
    ps -p "$java_pid" -o pcpu= 2>/dev/null | tr -d ' ' || echo "0"
}

# =============================================================================
# Get native Java memory usage
# =============================================================================
get_native_memory() {
    local java_pid
    java_pid=$(pgrep -f "HytaleServer.jar" | head -n1)
    
    if [[ -z "$java_pid" ]]; then
        echo "0,0"
        return
    fi
    
    # Get RSS (resident set size) in KB, convert to MB
    local rss_kb
    rss_kb=$(ps -p "$java_pid" -o rss= 2>/dev/null | tr -d ' ' || echo "0")
    local rss_mb
    rss_mb=$(echo "scale=2; $rss_kb / 1024" | bc)
    local pmem
    pmem=$(ps -p "$java_pid" -o pmem= 2>/dev/null | tr -d ' ' || echo "0")
    
    echo "${rss_mb},${pmem}"
}

# =============================================================================
# Monitor mode - continuously collect metrics
# =============================================================================
monitor_continuous() {
    local mode="${MODE:-both}"  # both, docker, or native
    
    print_header "Resource Usage Monitor"
    log_info "Mode: $mode"
    log_info "Monitoring every ${INTERVAL}s for ${DURATION}s"
    log_info "Press Ctrl+C to stop early"
    echo ""
    
    mkdir -p "$OUTPUT_DIR"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local docker_file="${OUTPUT_DIR}/docker_${timestamp}.csv"
    local native_file="${OUTPUT_DIR}/native_${timestamp}.csv"
    
    # CSV headers (system-wide metrics only - entire VM)
    if [[ "$mode" == "both" ]] || [[ "$mode" == "docker" ]]; then
        echo "timestamp,cpu_percent,memory_mb,memory_percent" > "$docker_file"
    fi
    
    if [[ "$mode" == "both" ]] || [[ "$mode" == "native" ]]; then
        echo "timestamp,cpu_percent,memory_mb,memory_percent" > "$native_file"
    fi
    
    local start_time
    start_time=$(date +%s)
    local elapsed=0
    local sample_count=0
    
    while [[ $elapsed -lt $DURATION ]]; do
        sample_count=$((sample_count + 1))
        local current_time
        current_time=$(date +"%Y-%m-%d %H:%M:%S")
        
        # Docker metrics (system-wide only - entire VM to capture Docker overhead)
        local docker_cpu docker_mem docker_mem_percent
        if [[ "$mode" == "both" ]] || [[ "$mode" == "docker" ]]; then
            # Get system-wide metrics (captures Docker daemon, container, and all overhead)
            local system_metrics
            system_metrics=$(get_system_metrics)
            docker_cpu=$(echo "$system_metrics" | cut -d',' -f1)
            docker_mem=$(echo "$system_metrics" | cut -d',' -f2)
            docker_mem_percent=$(echo "$system_metrics" | cut -d',' -f3)
            
            echo "${current_time},${docker_cpu},${docker_mem},${docker_mem_percent}" >> "$docker_file"
        fi
        
        # Native metrics (system-wide only - entire VM)
        local native_cpu native_mem native_mem_percent
        if [[ "$mode" == "both" ]] || [[ "$mode" == "native" ]]; then
            # Get system-wide metrics (captures Java process + OS overhead)
            local system_metrics
            system_metrics=$(get_system_metrics)
            native_cpu=$(echo "$system_metrics" | cut -d',' -f1)
            native_mem=$(echo "$system_metrics" | cut -d',' -f2)
            native_mem_percent=$(echo "$system_metrics" | cut -d',' -f3)
            
            echo "${current_time},${native_cpu},${native_mem},${native_mem_percent}" >> "$native_file"
        fi
        
        # Display status (system-wide metrics - entire VM)
        if [[ "$mode" == "both" ]]; then
            printf "\r[%d/%d] Docker (VM): CPU=%.1f%% Mem=%.1fMB (%.1f%%) | Native (VM): CPU=%.1f%% Mem=%.1fMB (%.1f%%)     " \
                "$sample_count" \
                "$((DURATION / INTERVAL))" \
                "$docker_cpu" \
                "$docker_mem" \
                "$docker_mem_percent" \
                "$native_cpu" \
                "$native_mem" \
                "$native_mem_percent" >&2
        elif [[ "$mode" == "docker" ]]; then
            printf "\r[%d/%d] Docker (VM): CPU=%.1f%% Mem=%.1fMB (%.1f%%)     " \
                "$sample_count" \
                "$((DURATION / INTERVAL))" \
                "$docker_cpu" \
                "$docker_mem" \
                "$docker_mem_percent" >&2
        elif [[ "$mode" == "native" ]]; then
            printf "\r[%d/%d] Native (VM): CPU=%.1f%% Mem=%.1fMB (%.1f%%)     " \
                "$sample_count" \
                "$((DURATION / INTERVAL))" \
                "$native_cpu" \
                "$native_mem" \
                "$native_mem_percent" >&2
        fi
        
        sleep "$INTERVAL"
        
        elapsed=$(($(date +%s) - start_time))
    done
    
    echo "" >&2
    log_success "Monitoring complete. Results saved to:"
    if [[ "$mode" == "both" ]] || [[ "$mode" == "docker" ]]; then
        log_info "  Docker: $docker_file"
    fi
    if [[ "$mode" == "both" ]] || [[ "$mode" == "native" ]]; then
        log_info "  Native: $native_file"
    fi
}

# =============================================================================
# Snapshot mode - single measurement
# =============================================================================
snapshot() {
    print_header "Resource Usage Snapshot"
    
    local docker_cpu
    docker_cpu=$(get_docker_cpu)
    local docker_mem
    docker_mem=$(get_docker_memory)
    
    local native_cpu
    native_cpu=$(get_native_cpu)
    local native_mem
    native_mem=$(get_native_memory)
    
    echo ""
    echo -e "${C_BOLD}Docker Container (${CONTAINER_NAME}):${C_RESET}"
    if [[ "$docker_cpu" != "0" ]] || [[ "$docker_mem" != "0,0" ]]; then
        echo "  CPU:    ${docker_cpu}%"
        echo "  Memory: $(echo "$docker_mem" | cut -d',' -f1) ($(echo "$docker_mem" | cut -d',' -f2)%)"
    else
        echo -e "  ${C_YELLOW}Container not running${C_RESET}"
    fi
    
    echo ""
    echo -e "${C_BOLD}Native Java Process:${C_RESET}"
    if [[ "$native_cpu" != "0" ]] || [[ "$native_mem" != "0,0" ]]; then
        echo "  CPU:    ${native_cpu}%"
        echo "  Memory: $(echo "$native_mem" | cut -d',' -f1)MB ($(echo "$native_mem" | cut -d',' -f2)%)"
    else
        echo -e "  ${C_YELLOW}Java process not running${C_RESET}"
    fi
    
    echo ""
}

# =============================================================================
# Calculate statistics from CSV column
# =============================================================================
calc_stats() {
    local file="$1"
    local col="$2"  # Column number (1-based)
    local samples
    samples=$(tail -n +2 "$file" | cut -d',' -f"$col" | awk '
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
                # Median calculation (requires sorting)
                printf "%.2f %.2f %.2f %.2f %d", mean, stddev, min, max, count
            } else {
                printf "0 0 0 0 0"
            }
        }
    ')
    echo "$samples"
}

# =============================================================================
# Compare CSV files
# =============================================================================
compare_csv() {
    local docker_file="$1"
    local native_file="$2"
    
    if [[ ! -f "$docker_file" ]] || [[ ! -f "$native_file" ]]; then
        log_error "CSV files not found"
        exit 1
    fi
    
    print_header "Statistical Comparison Summary"
    
    # Calculate statistics for Docker
    local docker_cpu_stats docker_mem_stats
    docker_cpu_stats=$(calc_stats "$docker_file" 2)  # CPU is column 2
    docker_mem_stats=$(calc_stats "$docker_file" 3)  # Memory is column 3
    
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
    
    # Calculate statistics for Native
    local native_cpu_stats native_mem_stats
    native_cpu_stats=$(calc_stats "$native_file" 2)  # CPU is column 2
    native_mem_stats=$(calc_stats "$native_file" 4)  # Memory is column 4 (RSS)
    
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
    
    echo ""
    echo -e "${C_BOLD}Average Usage:${C_RESET}"
    printf "  Docker:  CPU=%.2f%%, Memory=%.2fMB\n" "$docker_avg_cpu" "$docker_avg_mem"
    printf "  Native:  CPU=%.2f%%, Memory=%.2fMB\n" "$native_avg_cpu" "$native_avg_mem"
    
    echo ""
    echo -e "${C_BOLD}Peak Usage:${C_RESET}"
    printf "  Docker:  CPU=%.2f%%, Memory=%.2fMB\n" "$docker_max_cpu" "$docker_max_mem"
    printf "  Native:  CPU=%.2f%%, Memory=%.2fMB\n" "$native_max_cpu" "$native_max_mem"
    
    echo ""
    if command -v bc >/dev/null 2>&1; then
        local cpu_diff
        cpu_diff=$(echo "scale=2; $docker_avg_cpu - $native_avg_cpu" | bc)
        local mem_diff
        mem_diff=$(echo "scale=2; $docker_avg_mem - $native_avg_mem" | bc)
        echo -e "${C_BOLD}Difference (Docker - Native):${C_RESET}"
        printf "  CPU:    %.2f%%\n" "$cpu_diff"
        printf "  Memory: %.2fMB\n" "$mem_diff"
    fi
}

# =============================================================================
# List CSV files for comparison
# =============================================================================
list_csv_files() {
    print_header "Available CSV Files for Comparison"
    
    local docker_files
    mapfile -t docker_files < <(find "$OUTPUT_DIR" -name "docker_*.csv" -type f 2>/dev/null | sort -r | head -10)
    local native_files
    mapfile -t native_files < <(find "$OUTPUT_DIR" -name "native_*.csv" -type f 2>/dev/null | sort -r | head -10)
    
    echo -e "${C_BOLD}Docker CSV files:${C_RESET}"
    if [[ ${#docker_files[@]} -gt 0 ]]; then
        for i in "${!docker_files[@]}"; do
            local file="${docker_files[$i]}"
            local basename_file
            basename_file=$(basename "$file")
            echo "  [$((i+1))] $basename_file"
        done
    else
        echo "  No Docker CSV files found"
    fi
    
    echo ""
    echo -e "${C_BOLD}Native CSV files:${C_RESET}"
    if [[ ${#native_files[@]} -gt 0 ]]; then
        for i in "${!native_files[@]}"; do
            local file="${native_files[$i]}"
            local basename_file
            basename_file=$(basename "$file")
            echo "  [$((i+1))] $basename_file"
        done
    else
        echo "  No Native CSV files found"
    fi
    
    echo ""
    echo "Usage: ./tools/compare-resources.sh compare <docker_csv> <native_csv>"
}

# =============================================================================
# Main
# =============================================================================
main() {
    case "${1:-snapshot}" in
        snapshot)
            check_dependencies
            snapshot
            ;;
        monitor|record)
            check_dependencies
            monitor_continuous
            ;;
        compare)
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 compare <docker_csv> <native_csv>"
                echo ""
                list_csv_files
                exit 1
            fi
            compare_csv "$2" "$3"
            ;;
        list)
            list_csv_files
            ;;
        *)
            echo "Usage: $0 {snapshot|monitor|record|compare|list}"
            echo ""
            echo "Commands:"
            echo "  snapshot              - Take a single snapshot of current usage"
            echo "  monitor [docker|native|both] - Record metrics to CSV files"
            echo "  record [docker|native] - Alias for monitor (record one at a time)"
            echo "  compare <f1> <f2>     - Compare two CSV files and show statistics"
            echo "  list                  - List available CSV files"
            echo ""
            echo "Examples:"
            echo "  # Record Docker metrics (while Docker server is running)"
            echo "  MODE=docker DURATION=60 ./tools/compare-resources.sh record"
            echo ""
            echo "  # Record Native metrics (while native server is running)"
            echo "  MODE=native DURATION=60 ./tools/compare-resources.sh record"
            echo ""
            echo "  # Compare two specific CSV files"
            echo "  ./tools/compare-resources.sh compare metrics/docker_*.csv metrics/native_*.csv"
            echo ""
            echo "Environment variables:"
            echo "  MODE=docker|native|both - What to monitor (default: both)"
            echo "  INTERVAL=5             - Seconds between samples (monitor mode)"
            echo "  DURATION=60            - Total duration in seconds (monitor mode)"
            exit 1
            ;;
    esac
}

main "$@"
