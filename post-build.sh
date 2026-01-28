#!/bin/bash

# Post-build script to configure SSH access for LAN8651 development
# Sets root password to "microchip" and ensures SSH service is enabled

TARGET_DIR="$1"

echo "Configuring SSH access for development..."

# Set root password to "microchip" 
# Generate password hash for "microchip"
PASSWORD_HASH='$6$LpHS81GZTujUm.z0$gR.zzYoP6PXWI.kOSi90eICWZePeBF4K2K58DozsAlg9izQpRpoiaCARoj4PrmrQ2X496nxoY.sSvwQhbuHXm.'

# Update shadow file with new root password
if [ -f "$TARGET_DIR/etc/shadow" ]; then
    # Backup original shadow file
    cp "$TARGET_DIR/etc/shadow" "$TARGET_DIR/etc/shadow.orig"
    
    # Replace root password line
    sed -i "s|^root:[^:]*:|root:$PASSWORD_HASH:|" "$TARGET_DIR/etc/shadow"
    echo "✓ Root password set to 'microchip'"
else
    echo "Warning: /etc/shadow not found in target"
fi

# Ensure dropbear SSH service is enabled
if [ -d "$TARGET_DIR/etc/init.d" ]; then
    # Enable dropbear service
    if [ -f "$TARGET_DIR/etc/init.d/S50dropbear" ]; then
        chmod +x "$TARGET_DIR/etc/init.d/S50dropbear"
        echo "✓ Dropbear SSH service enabled"
    fi
fi

# Create dropbear config directory if it doesn't exist
mkdir -p "$TARGET_DIR/etc/dropbear"

# Ensure proper permissions
chmod 755 "$TARGET_DIR/etc/dropbear"
chmod 600 "$TARGET_DIR/etc/shadow" 2>/dev/null

echo "SSH configuration completed."
echo "Root login enabled with password: microchip"
# Ensure LAN865x scripts are present
OVERLAY_DIR="$(dirname "$0")/rootfs_overlay"

# Copy S09lan865xmodprobe if missing
if [ -f "$OVERLAY_DIR/etc/init.d/S09lan865xmodprobe" ]; then
    if [ ! -f "$TARGET_DIR/etc/init.d/S09lan865xmodprobe" ]; then
        cp "$OVERLAY_DIR/etc/init.d/S09lan865xmodprobe" "$TARGET_DIR/etc/init.d/"
        chmod 755 "$TARGET_DIR/etc/init.d/S09lan865xmodprobe"
        echo "✓ S09lan865xmodprobe copied to target."
    fi
fi

# Copy load_lan865x.sh if missing
if [ -f "$OVERLAY_DIR/root/load_lan865x.sh" ]; then
    if [ ! -f "$TARGET_DIR/root/load_lan865x.sh" ]; then
        cp "$OVERLAY_DIR/root/load_lan865x.sh" "$TARGET_DIR/root/"
        chmod 755 "$TARGET_DIR/root/load_lan865x.sh"
        echo "✓ load_lan865x.sh copied to target."
    fi
fi