#!/bin/bash
# LCD Display Driver Database for PITLAB Wallet
# Maps display names to their configurations

# Display configuration format:
# DISPLAY_NAME: script_name:overlay_file:default_rotation:width:height:touch_type:config_params[:dma_settings]

# Board-specific DMA settings
readonly PI3_DMA="dma_channels=4,5"
readonly PI4_DMA="dma_channels=4,5"
readonly PI5_DMA="dma_channels=14,15:dma_bufsize=65536"

declare -A LCD_DRIVERS

# GPIO/SPI-based displays (with DMA settings for different boards)
LCD_DRIVERS[lcd35]="LCD35-show:tft35a:90:480:320:ads7846:hdmi_cvt=480x320:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[lcd32]="LCD32-show:tft9341:270:480:360:ads7846:hdmi_cvt=480x360:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[lcd28]="LCD28-show:tft9341:270:480:360:ads7846:hdmi_cvt=480x360:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[lcd24]="LCD24-show:tft9341:270:480:360:ads7846:hdmi_cvt=480x360:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[lcd5]="LCD5-show::0:800:480:ads7846:hdmi_cvt=800x480:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"

# MHS/MPI series (with DMA settings)
LCD_DRIVERS[mhs35]="MHS35-show:mhs35:90:480:320:ads7846:hdmi_cvt=480x320:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[mhs32]="MHS32-show:tft9341:270:480:360:ads7846:hdmi_cvt=480x360:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[mhs24]="MHS24-show:tft9341:270:480:360:ads7846:hdmi_cvt=480x360:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[mpi3508]="MPI3508-show::90:480:320:ads7846:hdmi_cvt=480x320:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[mpi4008]="MPI4008-show::0:800:480:ft6236:hdmi_cvt=800x480:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"

# HDMI displays (no DMA needed)
LCD_DRIVERS[lcd7b]="LCD7B-show::0:800:480::hdmi_cvt=800x480"
LCD_DRIVERS[lcd7c]="LCD7C-show::0:1024:600::hdmi_cvt=1024x600"
LCD_DRIVERS[lcd7h]="LCD7H-show::0:1024:600:ft6236:hdmi_cvt=1024x600"
LCD_DRIVERS[lcd7s]="LCD7S-show::0:1024:600:ft6236:hdmi_cvt=1024x600"
LCD_DRIVERS[lcd101h]="LCD101H-show::0:1024:600:ft6236:hdmi_timings=1024x600"
LCD_DRIVERS[lcd101y]="LCD101Y-show::0:1280:800:ft6236:hdmi_timings=1280x800"
LCD_DRIVERS[lcd55]="LCD55-show::0:1920:1080::hdmi_cvt=1920x1080"

# Special displays
LCD_DRIVERS[lcd154]="LCD154-show::90:300:300:ads7846:hdmi_cvt=300x300:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[nano24]="NANO24-show::0:240:240::hdmi_cvt=240x240"

# Generic/Waveshare compatibility aliases
LCD_DRIVERS[waveshare35a]="LCD35-show:tft35a:90:480:320:ads7846:hdmi_cvt=480x320:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"
LCD_DRIVERS[waveshare32b]="LCD32-show:tft9341:270:480:360:ads7846:hdmi_cvt=480x360:${PI3_DMA}|${PI4_DMA}|${PI5_DMA}"

# HDMI standard (no special driver)
LCD_DRIVERS[hdmi]="HDMI::0:1920:1080::hdmi_standard"

# Constants
readonly CALIBRATION_FILE="/var/lib/pitlab-wallet/pointercal"
readonly TOUCHSCREEN_RULES="/etc/udev/rules.d/95-touchscreen.rules"
readonly FBCP_PATH="/usr/local/bin/fbcp"

# Get display configuration
get_display_config() {
    local display="$1"
    local display_lower="${display,,}"  # Convert to lowercase
    local board="$2"    # Optional board parameter (pi3, pi4, pi5)
    
    if [[ -n "${LCD_DRIVERS[$display_lower]}" ]]; then
        local config="${LCD_DRIVERS[$display_lower]}"
        if [[ -n "$board" && "$config" == *":dma_channels"* ]]; then
            # Extract board-specific DMA settings
            local dma_settings=$(echo "$config" | cut -d':' -f8)
            case "$board" in
                pi3) dma_settings=$(echo "$dma_settings" | cut -d'|' -f1) ;;
                pi4) dma_settings=$(echo "$dma_settings" | cut -d'|' -f2) ;;
                pi5) dma_settings=$(echo "$dma_settings" | cut -d'|' -f3) ;;
            esac
            # Replace DMA settings in config
            config="${config%:*}:$dma_settings"
        fi
        echo "$config"
        return 0
    else
        # Check if it's a custom overlay
        echo "CUSTOM:${display}:0:800:480::custom"
        return 1
    fi
}

# Parse display configuration
parse_display_config() {
    local config="$1"
    local field="$2"
    
    local script_name=$(echo "$config" | cut -d':' -f1)
    local overlay_file=$(echo "$config" | cut -d':' -f2)
    local default_rotation=$(echo "$config" | cut -d':' -f3)
    local width=$(echo "$config" | cut -d':' -f4)
    local height=$(echo "$config" | cut -d':' -f5)
    local touch_type=$(echo "$config" | cut -d':' -f6)
    local config_params=$(echo "$config" | cut -d':' -f7)
    local dma_settings=$(echo "$config" | cut -d':' -f8)
    
    case "$field" in
        script) echo "$script_name" ;;
        overlay) echo "$overlay_file" ;;
        rotation) echo "$default_rotation" ;;
        width) echo "$width" ;;
        height) echo "$height" ;;
        touch) echo "$touch_type" ;;
        params) echo "$config_params" ;;
        dma) echo "$dma_settings" ;;
        *) echo "" ;;
    esac
}

# Check if display needs FBCP (framebuffer copy for SPI displays)
needs_fbcp() {
    local display="$1"
    local config=$(get_display_config "$display")
    local script=$(parse_display_config "$config" "script")
    local overlay=$(parse_display_config "$config" "overlay")
    
    # FBCP needed for all displays with overlay files (indicates SPI/GPIO displays)
    # HDMI displays and those without overlay don't need FBCP
    [[ -n "$overlay" && "$script" != "HDMI" ]]
}

# Configure touchscreen based on display type
configure_touchscreen() {
    local display="$1"
    local config=$(get_display_config "$display")
    local touch_type=$(parse_display_config "$config" "touch")
    
    if [[ -n "$touch_type" && "$touch_type" != "none" ]]; then
        # Create udev rules for touchscreen
        cat > "$TOUCHSCREEN_RULES" << EOF
ACTION=="add", KERNEL=="event*", ATTRS{name}=="${touch_type}", TAG+="systemd", ENV{SYSTEMD_WANTS}="touchscreen-calibration.service"
EOF
        
        # Set up calibration if needed
        if [[ "$touch_type" == "ads7846" ]]; then
            # Resistive touchscreens need calibration
            echo "DISPLAY=:0 XAUTHORITY=/home/pi/.Xauthority xinput_calibrator --output-filename $CALIBRATION_FILE" > /usr/local/bin/calibrate-touchscreen.sh
            chmod +x /usr/local/bin/calibrate-touchscreen.sh
        fi
    fi
}

# Configure FBCP service for SPI displays
configure_fbcp() {
    local display="$1"
    if needs_fbcp "$display"; then
        # Create systemd service for FBCP
        cat > "/etc/systemd/system/fbcp.service" << EOF
[Unit]
Description=Framebuffer Copy
After=graphical.target
Before=touchscreen-calibration.service

[Service]
Type=simple
ExecStart=$FBCP_PATH
Restart=always

[Install]
WantedBy=graphical.target
EOF
        systemctl enable fbcp.service
    fi
}

# List all supported displays
list_displays() {
    echo "Supported LCD Displays:"
    echo "======================="
    printf "%-20s %-15s %-12s %-15s %s\n" "DISPLAY" "SIZE" "TOUCH" "DRIVER" "FBCP"
    echo "------------------------------------------------------------------------"
    for display in "${!LCD_DRIVERS[@]}"; do
        local config="${LCD_DRIVERS[$display]}"
        local size="$(parse_display_config "$config" "width")x$(parse_display_config "$config" "height")"
        local touch=$(parse_display_config "$config" "touch")
        local driver=$(parse_display_config "$config" "overlay")
        local needs_fb=$(needs_fbcp "$display" && echo "Yes" || echo "No")
        [[ -z "$driver" ]] && driver="HDMI"
        [[ -z "$touch" ]] && touch="-"
        printf "%-20s %-15s %-12s %-15s %s\n" "$display" "$size" "$touch" "$driver" "$needs_fb"
    done | sort
}

# Configure display settings for board
configure_display() {
    local display="$1"
    local board="$2"
    local config_file="$3"
    local rotation="${4:-0}"
    
    local config=$(get_display_config "$display" "$board")
    local overlay=$(parse_display_config "$config" "overlay")
    local params=$(parse_display_config "$config" "params")
    local dma=$(parse_display_config "$config" "dma")
    
    # Apply display configuration
    [[ -n "$overlay" ]] && echo "dtoverlay=$overlay" >> "$config_file"
    [[ -n "$params" ]] && echo "$params" >> "$config_file"
    [[ -n "$dma" ]] && echo "$dma" >> "$config_file"
    
    # Configure rotation
    if [[ "$rotation" != "0" ]]; then
        if [[ "$display" == "hdmi" ]]; then
            echo "display_hdmi_rotate=$rotation" >> "$config_file"
        else
            echo "display_rotate=$rotation" >> "$config_file"
        fi
    fi
    
    # Set up touchscreen if needed
    configure_touchscreen "$display"
    
    # Configure FBCP if needed
    configure_fbcp "$display"
}

# Export functions and variables for sourcing
export -f get_display_config
export -f parse_display_config
export -f needs_fbcp
export -f list_displays
export -f configure_display
export -f configure_touchscreen
export -f configure_fbcp
