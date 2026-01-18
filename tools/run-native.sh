#!/usr/bin/env bash
# =============================================================================
# Hytale Server Native Launcher
# Runs Hytale server natively with Java (without Docker)
# Follows official Hytale server requirements
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${DATA_DIR:-${PROJECT_ROOT}/data}"
SERVER_DIR="${DATA_DIR}"
SERVER_JAR="${SERVER_DIR}/Server/HytaleServer.jar"
ASSETS_ZIP="${SERVER_DIR}/Assets.zip"
AOT_CACHE="${SERVER_DIR}/Server/HytaleServer.aot"

# Java settings (can be overridden via environment)
JAVA_OPTS="${JAVA_OPTS:--Xms4G -Xmx8G}"
SERVER_PORT="${SERVER_PORT:-5520}"
USE_AOT_CACHE="${USE_AOT_CACHE:-true}"
DISABLE_SENTRY="${DISABLE_SENTRY:-false}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

# Java version requirement (Hytale requires Java 25+)
REQUIRED_JAVA_MAJOR=25

# =============================================================================
# Colors for output
# =============================================================================
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'

# =============================================================================
# Helper functions
# =============================================================================
print_header() {
    echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════${C_RESET}" >&2
    echo -e "${C_BOLD}  $1${C_RESET}" >&2
    echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════${C_RESET}" >&2
}

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

# =============================================================================
# Check if Java is installed and meets version requirements
# =============================================================================
check_java_version() {
    if ! command -v java >/dev/null 2>&1; then
        return 1  # Java not found
    fi
    
    local version_output
    version_output=$(java --version 2>&1 | head -n1)
    
    # Extract major version number
    # Format: "openjdk version "25.0.1" 2024-..." or similar
    local major_version
    major_version=$(echo "$version_output" | awk -F'"' '{print $2}' | awk -F'.' '{print $1}')
    
    # Handle versions like "25" or "25.0.1"
    if [[ -z "$major_version" ]] || ! [[ "$major_version" =~ ^[0-9]+$ ]]; then
        # Fallback: try to extract from version string
        major_version=$(echo "$version_output" | grep -oE '[0-9]+' | head -n1)
    fi
    
    if [[ -z "$major_version" ]] || ! [[ "$major_version" =~ ^[0-9]+$ ]]; then
        log_warn "Could not determine Java version from: $version_output"
        return 2  # Could not determine version
    fi
    
    if [[ $major_version -ge $REQUIRED_JAVA_MAJOR ]]; then
        return 0  # Version OK
    else
        return 2  # Version too old
    fi
}

# =============================================================================
# Install Java 25 (Eclipse Temurin)
# Following official Hytale requirements: https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual
# Eclipse Temurin is distributed by Eclipse Adoptium (adoptium.net) - a vendor-neutral,
# open-source project under the Eclipse Foundation (successor to AdoptOpenJDK)
# =============================================================================
install_java() {
    log_info "Java ${REQUIRED_JAVA_MAJOR} (Eclipse Temurin) is required for Hytale"
    log_info "Installing Eclipse Temurin via Eclipse Adoptium (adoptium.net)"
    
    # Detect OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. Please install Java ${REQUIRED_JAVA_MAJOR} manually."
        log_info "Visit: https://adoptium.net/"
        exit 1
    fi
    
    source /etc/os-release
    
    # Check if running as root or has sudo
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        log_error "Please run as root or install sudo to install Java"
        exit 1
    fi
    
    # Ubuntu/Debian
    if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        log_info "Detected Debian/Ubuntu. Installing Eclipse Temurin ${REQUIRED_JAVA_MAJOR}..."
        
        # Install required packages
        $SUDO apt-get update
        $SUDO apt-get install -y wget curl gnupg lsb-release
        
        # Add Adoptium repository
        # Use the modern method (without deprecated apt-key)
        $SUDO mkdir -p /etc/apt/keyrings
        wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | $SUDO tee /etc/apt/keyrings/adoptium.asc >/dev/null
        echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | $SUDO tee /etc/apt/sources.list.d/adoptium.list >/dev/null
        
        $SUDO apt-get update
        $SUDO apt-get install -y "temurin-${REQUIRED_JAVA_MAJOR}-jdk"
        
        # Update alternatives if multiple Java versions exist
        if command -v update-alternatives >/dev/null 2>&1; then
            $SUDO update-alternatives --auto java 2>/dev/null || true
        fi
        
        log_success "Java ${REQUIRED_JAVA_MAJOR} installed"
        
    # Fedora/RHEL/CentOS
    elif [[ "$ID" == "fedora" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "centos" ]] || [[ "$ID_LIKE" == *"fedora"* ]] || [[ "$ID_LIKE" == *"rhel"* ]]; then
        log_info "Detected Fedora/RHEL/CentOS. Installing Eclipse Temurin ${REQUIRED_JAVA_MAJOR}..."
        
        $SUDO dnf install -y wget curl
        
        # Add Adoptium repository for RHEL/Fedora
        $SUDO dnf install -y dnf-plugins-core
        $SUDO dnf config-manager --add-repo https://packages.adoptium.net/artifactory/rpm
        
        $SUDO dnf install -y "temurin-${REQUIRED_JAVA_MAJOR}-jdk"
        
        log_success "Java ${REQUIRED_JAVA_MAJOR} installed"
        
    else
        log_error "Unsupported OS: $ID"
        log_info "Please install Java ${REQUIRED_JAVA_MAJOR} manually from: https://adoptium.net/"
        exit 1
    fi
    
    # Verify installation
    if ! check_java_version; then
        log_error "Java installation verification failed"
        log_info "Please verify Java ${REQUIRED_JAVA_MAJOR} is installed and in PATH"
        exit 1
    fi
}

# =============================================================================
# Verify server files exist
# =============================================================================
verify_server_files() {
    if [[ ! -d "$SERVER_DIR" ]]; then
        log_error "Server directory not found: $SERVER_DIR"
        log_info "Expected directory structure:"
        log_info "  $SERVER_DIR/Server/HytaleServer.jar"
        log_info "  $SERVER_DIR/Assets.zip"
        exit 1
    fi
    
    if [[ ! -f "$SERVER_JAR" ]]; then
        log_error "Server JAR not found: $SERVER_JAR"
        log_info "The server files may need to be downloaded first."
        log_info "You can run the Docker setup once to download files, or use hytale-downloader manually."
        exit 1
    fi
    
    if [[ ! -f "$ASSETS_ZIP" ]]; then
        log_warn "Assets.zip not found: $ASSETS_ZIP"
        log_warn "The server may not start without assets."
    fi
    
    log_success "Server files verified"
}

# =============================================================================
# Build Java launch command as an array
# =============================================================================
build_launch_command_array() {
    local cmd=()
    
    cmd+=("java")
    
    # Split JAVA_OPTS into separate arguments
    # This handles spaces in options like "-Xms4G -Xmx8G"
    read -ra java_opts_array <<< "$JAVA_OPTS"
    cmd+=("${java_opts_array[@]}")
    
    # AOT cache (for faster startup)
    if [[ "$USE_AOT_CACHE" == "true" ]] && [[ -f "$AOT_CACHE" ]]; then
        cmd+=("-XX:AOTCache=${AOT_CACHE}")
        log_info "Using AOT cache: $AOT_CACHE"
    fi
    
    # Server JAR and required arguments
    cmd+=("-jar" "${SERVER_JAR}")
    cmd+=("--assets" "${ASSETS_ZIP}")
    cmd+=("--bind" "0.0.0.0:${SERVER_PORT}")
    
    # Optional flags
    if [[ "$DISABLE_SENTRY" == "true" ]]; then
        cmd+=("--disable-sentry")
    fi
    
    # Extra arguments (split if provided)
    if [[ -n "$EXTRA_ARGS" ]]; then
        read -ra extra_args_array <<< "$EXTRA_ARGS"
        cmd+=("${extra_args_array[@]}")
    fi
    
    # Output array contents (one per line for mapfile)
    printf '%s\n' "${cmd[@]}"
}

# =============================================================================
# Main
# =============================================================================
main() {
    print_header "Hytale Server Native Launcher"
    
    # Warn if running as root (server should run as normal user)
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root is not recommended for security reasons"
        log_info "The server will run as root. Consider running as a normal user instead."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check Java
    log_info "Checking Java installation..."
    if ! check_java_version; then
        local status=$?
        if [[ $status -eq 1 ]]; then
            log_warn "Java not found"
        elif [[ $status -eq 2 ]]; then
            local current_version
            current_version=$(java --version 2>&1 | head -n1 || echo "unknown")
            log_warn "Java version too old: $current_version"
        fi
        
        log_info "Java ${REQUIRED_JAVA_MAJOR}+ (Eclipse Temurin) is required"
        read -p "Install Java ${REQUIRED_JAVA_MAJOR} now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_java
        else
            log_error "Java ${REQUIRED_JAVA_MAJOR} is required. Please install it manually."
            log_info "Visit: https://adoptium.net/"
            exit 1
        fi
    else
        local java_version
        java_version=$(java --version 2>&1 | head -n1)
        log_success "Java version OK: $java_version"
    fi
    
    # Set JAVA_HOME if not set and Java 25 is in standard location
    if [[ -z "${JAVA_HOME:-}" ]]; then
        local java_path
        java_path=$(which java)
        if [[ "$java_path" == /usr/lib/jvm/* ]]; then
            export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$java_path")")")
            log_info "Set JAVA_HOME to: $JAVA_HOME"
        fi
    fi
    
    # Verify server files
    log_info "Verifying server files..."
    verify_server_files
    
    # Build launch command as array (avoids eval issues with special chars)
    local launch_cmd_array
    mapfile -t launch_cmd_array < <(build_launch_command_array)
    
    log_success "Starting Hytale server..."
    log_info "Port: ${SERVER_PORT}/UDP"
    log_info "Memory: ${JAVA_OPTS}"
    log_info "Server directory: ${SERVER_DIR}"
    echo ""
    echo -e "${C_BOLD}${C_GREEN}═══════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    
    # Change to server directory and run
    cd "$SERVER_DIR"
    exec "${launch_cmd_array[@]}"
}

# Run main function
main "$@"
