#!/bin/bash
# LCD Display Driver Database for PITLAB Wallet
# Maps display names to their LCD-show script configurations

# Display configuration format:
# DISPLAY_NAME: script_name:overlay_file:default_rotation:width:height:touch_type:config_params

declare -A LCD_DRIVERS

# GPIO/SPI-based displays (from goodtft/LCD-show)
LCD_DRIVERS[lcd35]="LCD35-show:tft35a:90:480:320:resistance:hdmi_cvt=480x320"
LCD_DRIVERS[lcd32]="LCD32-show:tft9341:270:480:360:resistance:hdmi_cvt=480x360"
LCD_DRIVERS[lcd28]="LCD28-show:tft9341:270:480:360:resistance:hdmi_cvt=480x360"
LCD_DRIVERS[lcd24]="LCD24-show:tft9341:270:480:360:resistance:hdmi_cvt=480x360"
LCD_DRIVERS[lcd5]="LCD5-show::0:800:480:resistance:hdmi_cvt=800x480"
LCD_DRIVERS[mhs35]="MHS35-show:mhs35:90:480:320:resistance:hdmi_cvt=480x320"
LCD_DRIVERS[mhs32]="MHS32-show:tft9341:270:480:360:resistance:hdmi_cvt=480x360"
LCD_DRIVERS[mhs24]="MHS24-show:tft9341:270:480:360:resistance:hdmi_cvt=480x360"
LCD_DRIVERS[mpi3508]="MPI3508-show::90:480:320:resistance:hdmi_cvt=480x320"
LCD_DRIVERS[mpi4008]="MPI4008-show::0:800:480:capacitive:hdmi_cvt=800x480"

# HDMI displays
LCD_DRIVERS[lcd7b]="LCD7B-show::0:800:480::hdmi_cvt=800x480"
LCD_DRIVERS[lcd7c]="LCD7C-show::0:1024:600::hdmi_cvt=1024x600"
LCD_DRIVERS[lcd7h]="LCD7H-show::0:1024:600:capacitive:hdmi_cvt=1024x600"
LCD_DRIVERS[lcd7s]="LCD7S-show::0:1024:600:capacitive:hdmi_cvt=1024x600"
LCD_DRIVERS[lcd101h]="LCD101H-show::0:1024:600:capacitive:hdmi_timings=1024x600"
LCD_DRIVERS[lcd101y]="LCD101Y-show::0:1280:800:capacitive:hdmi_timings=1280x800"
LCD_DRIVERS[lcd55]="LCD55-show::0:1920:1080::hdmi_cvt=1920x1080"

# Special displays
LCD_DRIVERS[lcd154]="LCD154-show::90:300:300:resistance:hdmi_cvt=300x300"
LCD_DRIVERS[nano24]="NANO24-show::0:240:240::hdmi_cvt=240x240"

# Generic/Waveshare compatibility aliases
LCD_DRIVERS[waveshare35a]="LCD35-show:tft35a:90:480:320:resistance:hdmi_cvt=480x320"
LCD_DRIVERS[waveshare32b]="LCD32-show:tft9341:270:480:360:resistance:hdmi_cvt=480x360"

# HDMI standard (no special driver)
LCD_DRIVERS[hdmi]="HDMI::0:1920:1080::hdmi_standard"

# Get display configuration
get_display_config() {
    local display="$1"
    local display_lower="${display,,}"  # Convert to lowercase
    
    if [[ -n "${LCD_DRIVERS[$display_lower]}" ]]; then
        echo "${LCD_DRIVERS[$display_lower]}"
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
    
    case "$field" in
        script) echo "$script_name" ;;
        overlay) echo "$overlay_file" ;;
        rotation) echo "$default_rotation" ;;
        width) echo "$width" ;;
        height) echo "$height" ;;
        touch) echo "$touch_type" ;;
        params) echo "$config_params" ;;
        *) echo "" ;;
    esac
}

# List all supported displays
list_displays() {
    echo "Supported LCD Displays:"
    echo "======================="
    for display in "${!LCD_DRIVERS[@]}"; do
        local config="${LCD_DRIVERS[$display]}"
        local script=$(parse_display_config "$config" "script")
        local size=$(parse_display_config "$config" "width")x$(parse_display_config "$config" "height")
        printf "  %-20s %s (%s)\n" "$display" "$script" "$size"
    done | sort
}

# Export functions and variables for sourcing
export -f get_display_config
export -f parse_display_config
export -f list_displays
