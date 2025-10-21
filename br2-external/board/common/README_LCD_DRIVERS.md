# LCD Display Driver Integration for PITLAB Wallet

This directory contains the LCD driver integration system that allows PITLAB wallet to support various TFT LCD displays from the goodtft/LCD-show repository.

## Architecture

The LCD driver system consists of three main components:

### 1. **lcd-drivers.sh** - Display Database
Database of supported LCD displays with their configurations:
- Display names and aliases
- Device tree overlay files
- Default rotations
- Screen resolutions
- Touch screen types
- Boot configuration parameters

### 2. **post-image.sh** - Image Configuration Script
Buildroot post-image hook that configures the SD card image:
- Modifies `/boot/config.txt` with display-specific settings
- Copies device tree overlays
- Configures touchscreen calibration
- Sets up framebuffer copy (FBCP) for SPI displays
- Creates display info file

### 3. **Build System Integration**
The main `build.sh` script passes display configuration to Buildroot via environment variables.

## Supported Displays

### GPIO/SPI Displays (via FBCP)
- **lcd35** - 3.5" 480x320 (Jun-Electron compatible)
- **lcd32** - 3.2" 480x360
- **lcd28** - 2.8" 480x360
- **lcd24** - 2.4" 480x360
- **mhs35, mhs32, mhs24** - MHS series displays

### HDMI Displays
- **lcd5** - 5" 800x480
- **lcd7b** - 7" 800x480
- **lcd7c** - 7" 1024x600
- **lcd7h/lcd7s** - 7" 1024x600 capacitive touch
- **lcd101h/lcd101y** - 10.1" displays
- **lcd55** - 5.5" 1920x1080

### Special Displays
- **lcd154** - 1.54" 300x300
- **nano24** - 2.4" 240x240
- **hdmi** - Standard HDMI output (no special driver)

Run `./build.sh --list-displays` for the complete list.

## Usage

### Build with Specific Display

```bash
# Basic usage (Jun-Electron 3.5" example)
./build.sh pi4 lcd35 90

# With explicit options
./build.sh --board pi4 --display lcd35 --rotation 90

# HDMI output
./build.sh pi4 hdmi 0

# Clean build
./build.sh pi4 lcd35 90 --clean
```

### Supported Rotations
- `0` - No rotation (landscape)
- `90` - Rotate 90° clockwise (portrait)
- `180` - Rotate 180° (inverted landscape)
- `270` - Rotate 270° clockwise (portrait, inverted)

### List All Displays

```bash
./build.sh --list-displays
```

## How It Works

### Build Process

1. **Build.sh Configuration**
   ```bash
   ./build.sh pi4 lcd35 90
   ```
   - Sets `PITLAB_DISPLAY=lcd35`
   - Sets `PITLAB_ROTATION=90`
   - Sets `PITLAB_LCD_SHOW_DIR=/path/to/lcd-show-fork`

2. **Buildroot Build**
   - Compiles kernel with necessary drivers
   - Builds rootfs with required packages
   - Calls post-image.sh hook

3. **Post-Image Configuration**
   - Looks up display in `lcd-drivers.sh` database
   - Configures `/boot/config.txt`:
     ```ini
     dtoverlay=tft35a:rotate=90
     hdmi_cvt 480 320 60 6 0 0 0
     ```
   - Copies device tree overlays
   - Sets up touchscreen calibration
   - Configures FBCP for SPI displays

4. **Final Image**
   - SD card image with pre-configured display
   - Boots directly to working display
   - No post-boot configuration needed

### Display Configuration Flow

```
Build Script → Environment Variables → Buildroot → post-image.sh
                                                          ↓
                                                   lcd-drivers.sh
                                                          ↓
                                              /boot/config.txt
                                              /etc/X11/xorg.conf.d/
                                              /etc/rc.local (FBCP)
```

## Adding New Displays

To add support for a new display:

### 1. Add to lcd-drivers.sh

```bash
LCD_DRIVERS[newdisplay]="SCRIPT:overlay:rotation:width:height:touch:params"
```

Example:
```bash
LCD_DRIVERS[mydisplay]="LCD35-show:tft35a:90:480:320:resistance:hdmi_cvt=480x320"
```

### 2. Add Calibration Files (if touch-enabled)

Copy calibration files from lcd-show-fork:
```bash
lcd-show-fork/usr/99-calibration.conf-35-90
lcd-show-fork/usr/99-calibration.conf-35-180
# etc...
```

### 3. Add Overlay Files (if custom)

Copy device tree overlays:
```bash
lcd-show-fork/usr/tft35a-overlay.dtb
```

### 4. Test

```bash
./build.sh pi4 mydisplay 90
```

## LCD-show Fork Integration

The lcd-show repository is OPTIONAL and only used to copy overlays/calibration when present.

If available, place it alongside this repo as `../lcd-show-fork` (default autodetect), or set `PITLAB_LCD_SHOW_DIR` to your path.

When absent, the build uses firmware-provided overlays where available and standard libinput defaults for touch.

### Optional Files from lcd-show-fork (if present)

- **Device Tree Overlays**: `usr/*.dtb`, `usr/*.dtbo`
- **Calibration Files**: `usr/99-calibration.conf-*`
- **FBCP Binary**: `usr/rpi-fbcp/` (optional; you can also build rpi-fbcp in Buildroot)

## Troubleshooting

### Display Not Working

1. **Check display name**:
   ```bash
   ./build.sh --list-displays
   ```

2. **Verify lcd-show-fork location**:
   ```bash
   ls ../lcd-show-fork/
   ```

3. **Check boot config**:
   Mount SD card and examine `/boot/config.txt`

4. **Review display info**:
   On running system: `cat /etc/pitlab-display.conf`

### Touchscreen Not Calibrated

1. Check calibration file exists:
   ```bash
   cat /etc/X11/xorg.conf.d/99-calibration.conf
   ```

2. Manually test with `xinput_calibrator` (if X11 available)

3. Add custom calibration:
   - Edit `lcd-drivers.sh`
   - Add calibration file to lcd-show-fork

### SPI Display Shows Nothing

1. **Verify FBCP is running**:
   ```bash
   ps aux | grep fbcp
   ```

2. **Check device tree overlay**:
   ```bash
   ls /boot/overlays/tft*.dtb*
   ```

3. **Ensure SPI is enabled**:
   ```bash
   grep "dtparam=spi=on" /boot/config.txt
   ```

## Technical Details

### Device Tree Overlays

SPI/GPIO displays require device tree overlays that configure:
- GPIO pin mappings
- SPI bus configuration
- Touch screen controller settings

Example overlay usage:
```ini
dtoverlay=tft35a:rotate=90
```

### FBCP (Framebuffer Copy)

SPI displays use FBCP to copy the main framebuffer to the display:
- Main FB: HDMI virtual framebuffer (480x320)
- SPI FB: Physical SPI display

FBCP runs as background daemon started in `/etc/rc.local`

### Boot Configuration Parameters

Common parameters in `/boot/config.txt`:

| Parameter | Purpose |
|-----------|---------|
| `dtoverlay` | Device tree overlay for display |
| `hdmi_force_hotplug` | Force HDMI output even without monitor |
| `hdmi_cvt` | Custom video timing for HDMI |
| `hdmi_group/mode` | HDMI output mode settings |
| `dtparam=spi=on` | Enable SPI bus |
| `dtparam=i2c_arm=on` | Enable I2C (for touch) |
| `display_rotate` | Hardware rotation (HDMI) |

## Files Modified by post-image.sh

| File | Purpose |
|------|---------|
| `/boot/config.txt` | Boot/display configuration |
| `/boot/overlays/*.dtb*` | Device tree overlays |
| `/etc/X11/xorg.conf.d/99-calibration.conf` | Touch calibration |
| `/etc/X11/xorg.conf.d/45-evdev.conf` | Input device config |
| `/etc/rc.local` | Startup scripts (FBCP) |
| `/etc/pitlab-display.conf` | Display info metadata |

## Environment Variables

Build system uses these variables:

| Variable | Set By | Used By |
|----------|--------|---------|
| `PITLAB_DISPLAY` | build.sh | post-image.sh |
| `PITLAB_ROTATION` | build.sh | post-image.sh |
| `PITLAB_LCD_SHOW_DIR` | build.sh | post-image.sh |

## References

- **LCD-show**: https://github.com/goodtft/LCD-show
- **Buildroot Manual**: https://buildroot.org/downloads/manual/manual.html
- **Raspberry Pi Config**: https://www.raspberrypi.com/documentation/computers/config_txt.html
- **Device Tree**: https://www.kernel.org/doc/Documentation/devicetree/
