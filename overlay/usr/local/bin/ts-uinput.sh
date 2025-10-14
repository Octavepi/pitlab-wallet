#!/bin/sh
# ts-uinput.sh - start tslib uinput remapper if available

set -eu

: "${TSLIB_TSDEVICE:=/dev/input/event0}"
: "${TSLIB_CALIBFILE:=/var/lib/pitlab-wallet/pointercal}"
: "${TSLIB_CONFFILE:=/etc/ts.conf}"
: "${TSLIB_PLUGINDIR:=/usr/lib/ts}"

export TSLIB_TSDEVICE TSLIB_CALIBFILE TSLIB_CONFFILE TSLIB_PLUGINDIR

if command -v ts_uinput >/dev/null 2>&1; then
  echo "Starting ts_uinput with device $TSLIB_TSDEVICE and calib $TSLIB_CALIBFILE"
  ts_uinput -d "$TSLIB_TSDEVICE" -v
else
  echo "ts_uinput not found; skipping uinput remap"
fi
