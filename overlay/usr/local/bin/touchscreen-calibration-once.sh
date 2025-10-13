#!/bin/sh
# touchscreen-calibration-once.sh
# Run touchscreen calibration on first boot only, save config to persistent location

CALIB_FILE="/var/lib/pi-trezor/pointercal"
PERSIST_DIR="/var/lib/pi-trezor"
MARK_FILE="$PERSIST_DIR/.calibrated"

mkdir -p "$PERSIST_DIR"

if [ ! -f "$MARK_FILE" ]; then
    echo "No touchscreen calibration found, running ts_calibrate..."
    ts_calibrate
    # If ts_calibrate writes to /etc/pointercal, move it to persistent location
    if [ -f /etc/pointercal ]; then
        mv /etc/pointercal "$CALIB_FILE"
    fi
    # Symlink for compatibility
    ln -sf "$CALIB_FILE" /etc/pointercal
    touch "$MARK_FILE"
else
    echo "Touchscreen calibration already exists. Skipping."
fi
