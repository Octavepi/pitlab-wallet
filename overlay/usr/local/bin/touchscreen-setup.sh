#!/bin/bash

# Pi-Trezor Touchscreen Setup Script
# Configures touchscreen devices and calibration

set -e

LOG_FILE="/var/log/touchscreen-setup.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

log_message "Pi-Trezor touchscreen setup starting..."

# Create necessary directories
mkdir -p /etc/X11/xorg.conf.d
mkdir -p /var/lib/trezor

# Detect touchscreen devices
TOUCHSCREEN_DEVICES=$(ls /dev/input/event* 2>/dev/null | head -5)
PRIMARY_TOUCHSCREEN=""

log_message "Scanning for touchscreen devices..."

for device in $TOUCHSCREEN_DEVICES; do
    if [ -c "$device" ]; then
        # Check if this is a touchscreen device
        if evtest --query "$device" EV_ABS ABS_X > /dev/null 2>&1 && \
           evtest --query "$device" EV_ABS ABS_Y > /dev/null 2>&1; then
            PRIMARY_TOUCHSCREEN="$device"
            log_message "Found primary touchscreen: $device"
            break
        fi
    fi
done

# Create tslib configuration
cat > /etc/ts.conf << 'EOF'
# Touchscreen configuration for Pi-Trezor
module_raw input
module pthres pmin=1
module variance delta=30
module dejitter delta=100
module linear
EOF

# Create default calibration file (will be updated by actual calibration)
cat > /etc/pointercal << 'EOF'
-67 -912 65536 -1477 -1 45590528 65536
EOF

# Set environment variables for tslib
cat > /etc/environment << EOF
TSLIB_TSDEVICE=${PRIMARY_TOUCHSCREEN:-/dev/input/event0}
TSLIB_CALIBFILE=/etc/pointercal
TSLIB_CONFFILE=/etc/ts.conf
TSLIB_PLUGINDIR=/usr/lib/ts
EOF

# Create X11 configuration for touchscreen
if [ -n "$PRIMARY_TOUCHSCREEN" ]; then
    cat > /etc/X11/xorg.conf.d/99-touchscreen.conf << EOF
Section "InputDevice"
    Identifier "Touchscreen"
    Driver "evdev"
    Option "Device" "${PRIMARY_TOUCHSCREEN}"
    Option "DeviceName" "Touchscreen"
    Option "MinX" "0"
    Option "MaxX" "4095"
    Option "MinY" "0" 
    Option "MaxY" "4095"
    Option "ReportingMode" "Raw"
    Option "SendCoreEvents" "true"
    Option "Calibration" "3936 227 268 3880"
EndSection
EOF
fi

# Create calibration helper script
cat > /usr/local/bin/calibrate-touchscreen << 'EOF'
#!/bin/bash

# Pi-Trezor touchscreen calibration utility

echo "Pi-Trezor Touchscreen Calibration"
echo "================================="
echo

if [ ! -c "$TSLIB_TSDEVICE" ]; then
    echo "Error: No touchscreen device found at $TSLIB_TSDEVICE"
    echo "Available input devices:"
    ls -la /dev/input/event*
    exit 1
fi

echo "Calibrating touchscreen at: $TSLIB_TSDEVICE"
echo "Please tap the crosshairs as they appear..."
echo

# Stop existing services temporarily
systemctl stop trezor-emu || true

# Run calibration
ts_calibrate

# Restart services
systemctl start trezor-emu || true

echo "Calibration complete!"
echo "New calibration saved to: $TSLIB_CALIBFILE"
EOF

chmod +x /usr/local/bin/calibrate-touchscreen

# Create touchscreen test script
cat > /usr/local/bin/test-touchscreen << 'EOF'
#!/bin/bash

# Pi-Trezor touchscreen test utility

echo "Pi-Trezor Touchscreen Test"
echo "========================="
echo "Touch the screen to see coordinates. Press Ctrl+C to exit."
echo

if [ ! -c "$TSLIB_TSDEVICE" ]; then
    echo "Error: No touchscreen device found"
    exit 1
fi

echo "Touchscreen device: $TSLIB_TSDEVICE"
echo "Calibration file: $TSLIB_CALIBFILE"
echo

# Run touchscreen test
ts_test
EOF

chmod +x /usr/local/bin/test-touchscreen

# Check if we need to run initial calibration
if [ ! -f "/var/lib/trezor/.calibrated" ]; then
    log_message "First boot detected - touchscreen will need calibration"
    log_message "Run 'calibrate-touchscreen' to calibrate the display"
    
    # Mark as needing calibration
    touch /var/lib/trezor/.needs_calibration
else
    log_message "Touchscreen already calibrated"
fi

log_message "Pi-Trezor touchscreen setup completed successfully"

# Set proper permissions
chmod 644 /etc/ts.conf /etc/pointercal
chmod 755 /usr/local/bin/calibrate-touchscreen /usr/local/bin/test-touchscreen

exit 0