# Pi-Trezor Scripts

This directory contains utility scripts for the Pi-Trezor project.

## Available Scripts

### validate-structure.sh

Validates the repository structure to ensure all required files and directories are present.

**Usage:**
```bash
./scripts/validate-structure.sh
```

**What it checks:**
- Root documentation files (README, LICENSE, etc.)
- BR2_EXTERNAL directory structure
- Package definitions
- Overlay files and directories
- CI/CD configuration
- File permissions
- No duplicate configuration files

This script is useful for:
- Verifying repository integrity after cloning
- Ensuring all required files are present before building
- CI/CD validation checks
- Debugging structure issues

**Exit codes:**
- `0`: All checks passed
- `1`: One or more checks failed

## Future Scripts

Additional utility scripts may be added here for:
- Pre-build environment validation
- Post-build verification
- Image signing and verification
- Automated testing helpers
