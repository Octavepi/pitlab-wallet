# Function to check if a command is available
check_command() {
    local cmd=$1
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command '$cmd' not found"
        return 1
    fi
}

# Check system dependencies
validate_dependencies() {
    log_step "Checking system dependencies..."
    local missing_deps=0
    local deps=(
        make
        gcc
        g++
        unzip
        wget
        cpio
        rsync
        bc
        dtc
        perl
    )

    for dep in "${deps[@]}"; do
        if ! check_command "$dep"; then
            missing_deps=$((missing_deps + 1))
        fi
    done

    if [ "$missing_deps" -gt 0 ]; then
        log_error "Missing $missing_deps required dependencies"
        log_info "On Debian/Ubuntu, run: sudo apt-get install build-essential unzip wget cpio rsync bc device-tree-compiler"
        exit 1
    fi

    log_info "All system dependencies satisfied"
}

# Check disk space
check_disk_space() {
    log_step "Checking available disk space..."
    local build_dir="buildroot/output"
    local required_space=$((15 * 1024 * 1024)) # 15GB in KB
    local available_space
    
    available_space=$(df -k . | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_error "Insufficient disk space. Required: 15GB, Available: $((available_space/1024/1024))GB"
        exit 1
    fi
    
    log_info "Sufficient disk space available: $((available_space/1024/1024))GB"
}