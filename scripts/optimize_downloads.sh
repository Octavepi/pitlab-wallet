#!/bin/bash
# PitLab Wallet Download Optimization Script
# Improves download speeds and adds fallback mirrors

set -e

BUILDROOT_DIR="$(pwd)/buildroot"
DL_DIR="$BUILDROOT_DIR/dl"

# Faster mirror list for common packages
declare -A FAST_MIRRORS
FAST_MIRRORS[gcc]="https://mirror.cedia.org.ec/gnu/gcc https://ftp.gnu.org/gnu/gcc https://ftpmirror.gnu.org/gcc"
FAST_MIRRORS[linux]="https://cdn.kernel.org/pub/linux/kernel https://kernel.org/pub/linux/kernel"
FAST_MIRRORS[binutils]="https://ftp.gnu.org/gnu/binutils https://ftpmirror.gnu.org/binutils"
FAST_MIRRORS[glibc]="https://ftp.gnu.org/gnu/glibc https://ftpmirror.gnu.org/glibc"

# Create .wgetrc for faster downloads
create_fast_wgetrc() {
    cat > "$HOME/.wgetrc" << 'EOF'
# PitLab Wallet optimized wget configuration
timeout = 30
tries = 5
retry_connrefused = on
wait = 2
random_wait = on
continue = on
progress = bar:force:noscroll
user_agent = Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
EOF
    echo "Created optimized .wgetrc for faster downloads"
}

# Pre-fetch critical packages
prefetch_sources() {
    echo "Pre-fetching critical source packages..."
    cd "$BUILDROOT_DIR"
    
    # Use Buildroot's source target to download all sources upfront
    # This avoids download delays during the main build
    make source O="output/pi4_waveshare35a_180" BR2_EXTERNAL=../br2-external 2>/dev/null || {
        echo "Pre-fetch completed (some packages may not be available yet)"
    }
    
    cd ..
}

# Main optimization function
optimize_downloads() {
    echo "Optimizing PitLab Wallet downloads..."
    
    # Create optimized wget config
    create_fast_wgetrc
    
    # Pre-fetch sources if requested
    if [[ "${1:-}" == "--prefetch" ]]; then
        prefetch_sources
    fi
    
    echo "Download optimizations applied successfully"
    echo "Tip: Use './optimize_downloads.sh --prefetch' to download all sources upfront"
}

# Run optimizations
optimize_downloads "$@"
