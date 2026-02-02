#!/usr/bin/env bash


# LOGFILE als 4. Parameter
LOGFILE="${4:-patch_log.txt}"
print_info()    { local ts="$(date '+%Y-%m-%d %H:%M:%S')"; echo -e "\033[1;36m[INFO]\033[0m [$ts] $*"; echo "[INFO] [$ts] $*" >> "$LOGFILE"; }
print_warning() { local ts="$(date '+%Y-%m-%d %H:%M:%S')"; echo -e "\033[1;33m[WARN]\033[0m [$ts] $*"; echo "[WARN] [$ts] $*" >> "$LOGFILE"; }
print_debug()   { local ts="$(date '+%Y-%m-%d %H:%M:%S')"; echo -e "\033[1;32m[DEBG]\033[0m [$ts] $*"; echo "[DEBG] [$ts] $*" >> "$LOGFILE"; }
print_error()   { local ts="$(date '+%Y-%m-%d %H:%M:%S')"; echo -e "\033[1;31m[ERROR]\033[0m [$ts] $*"; echo "[ERROR] [$ts] $*" >> "$LOGFILE"; exit 1; }


print_info "# Changes for LAN8651 development"
print_info ""
print_info "This document summarizes the changes and adjustments made for development with the LAN8651 Ethernet controller."
print_info ""
print_info "## Build process changes"
print_info "- Creation and adjustment of `post-build.sh` to configure SSH access and root password."
print_info "- Copying custom kernel and Buildroot configuration files."
print_info "- Updating the device tree with LAN8651 support."
print_info "- Setting up a rootfs overlay with specific adjustments for Dropbear SSH and network interfaces."
print_info "- Updating the LAN865x kernel driver."
print_info "- Creating an init script for automatic loading of the LAN865x module at system startup."
print_info "- Creating a load script for manual loading of the LAN865x module on the target system."
print_info ""
print_info "## Important files"
print_info "- `post-build.sh`: Configures SSH access and root password."
print_info "- `lan966x-pcb8291.dts`: Device tree source file with LAN8651 support."
print_info "- `lan865x.c`: Updated kernel driver file for the LAN865x Ethernet controller."
print_info "- `load_lan865x.sh`: Script to load the LAN865x kernel module on the target."
print_info "- `S09lan865xmodprobe`: Init script for automatic loading of the LAN865x module at boot."
print_info ""
print_info "## Notes"
print_info "- The root user is configured by default with the password 'microchip'. It is recommended to change this password after development."
print_info "- Ensure that the Dropbear SSH configuration meets the security requirements of your environment."


print_info "This script performs the following steps:"
print_info " 1. Create post-build.sh if not present"
print_info " 2. Copy custom configuration files (kernel/Buildroot)"
print_info " 3. Directory and file checks"
print_info " 4. Copy device tree and remove old DTBs"
print_info " 5. Copy and configure overlay (Dropbear, network)"
print_info " 6. Update kernel driver file (lan865x.c)"
print_info " 7. Set up Ethernet interfaces in the overlay"
print_info " 8. Create load script for the target"
print_info " 9. Set up kernel module autoload (overlay)"
print_info "10. Run build (make linux-reconfigure, make)"
print_info "11. Checks (DTB, overlay, Dropbear, autoload)"
print_info "12. Documentation of changes"
print_info "The following files and directories are required:"
print_info " - lan966x-pcb8291.dts"
print_info " - lan865x.c"
print_info " - linux.config"
print_info " - buildroot.config"
print_info " - board/mscc/common/rootfs_overlay/ (with content)"
print_info " - output/${1}/build/linux-custom/arch/arm/boot/dts/microchip/ (target for DTS/DTB)"
print_info " - output/${1}/build/ (build directory)"
print_info " - output/${1}/build/linux-custom/ (kernel build directory)"
print_info " - output/${1}/images/ (images directory)"
print_info " - BSP base directory ${2}"
#print_info "Please confirm with 'y' and Enter to continue, or abort with 'n'."
#read -r -p "Continue? [y/n]: " confirm
#if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
#    print_info "Aborted by user."
#    exit 1
#fi


REPO_DIR="$(realpath "$3")"
SCRIPT_DIR="$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
print_debug "SCRIPT_DIR: $SCRIPT_DIR"
BASE_DIR="$2"
case "$BASE_DIR" in
    /*) BASE_DIR="$BASE_DIR" ;;
    *) BASE_DIR="$(realpath "$SCRIPT_DIR/../$BASE_DIR")" ;;
esac
print_debug "BASE_DIR: $BASE_DIR"

# 1. Create post-build.sh im Buildroot-Quellverzeichnis anlegen
POST_BUILD_SH_BSP="$BASE_DIR/board/mscc/common/post-build.sh"
print_info "(Re)creating post-build.sh in BSP: $POST_BUILD_SH_BSP"
mkdir -p "$(dirname "$POST_BUILD_SH_BSP")"
rm -f "$POST_BUILD_SH_BSP"
cat > "$POST_BUILD_SH_BSP" <<'EOSH'
#!/usr/bin/env bash
set -euo pipefail

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

# Remove dangling symlink if $TARGET_DIR/etc/dropbear is a symlink
if [ -L "$TARGET_DIR/etc/dropbear" ]; then
    echo "Removing dangling symlink: $TARGET_DIR/etc/dropbear"
    rm -f "$TARGET_DIR/etc/dropbear"
fi
# Create dropbear config directory if it doesn't exist
mkdir -p "$TARGET_DIR/etc/dropbear" || true

# Ensure proper permissions
chmod 755 "$TARGET_DIR/etc/dropbear"
chmod 600 "$TARGET_DIR/etc/shadow" 2>/dev/null

echo "SSH configuration completed."
echo "Root login enabled with password: microchip"
EOSH
    chmod +x "$POST_BUILD_SH_BSP"
    print_info "post-build.sh was created automatically in BSP board/mscc/common/."
#!/usr/bin/env bash
set -euo pipefail



# 1. Initialization and parameter check
if [[ $# -lt 3 ]]; then
    print_error "At least three arguments (build config directory/BSP/repo) required!"
fi

BUILD_CONFIG="$1"
print_debug "BUILD_CONFIG: $BUILD_CONFIG"


# Project root is the parent directory of the script directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
print_debug "SCRIPT_DIR: $SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
print_debug "PROJECT_ROOT: $PROJECT_ROOT"

# All Buildroot/output/overlay paths relative to project root

OUTPUT_DIR="$BASE_DIR/output/$BUILD_CONFIG"
print_debug "OUTPUT_DIR: $OUTPUT_DIR"
BUILD_DIR="$OUTPUT_DIR"
print_debug "BUILD_DIR: $BUILD_DIR"
KERNEL_BUILD_DIR="$BUILD_DIR/build/linux-custom"
print_debug "KERNEL_BUILD_DIR: $KERNEL_BUILD_DIR"
TARGET_DTS_DIR="$KERNEL_BUILD_DIR/arch/arm/boot/dts/microchip"
print_debug "TARGET_DTS_DIR: $TARGET_DTS_DIR"
IMAGES_DIR="$OUTPUT_DIR/images"
print_debug "IMAGES_DIR: $IMAGES_DIR"
OVERLAY_SRC="$BASE_DIR/board/mscc/common/rootfs_overlay"
print_debug "OVERLAY_SRC: $OVERLAY_SRC"
BUILDROOT_CONFIG="$OUTPUT_DIR/.config"
print_debug "BUILDROOT_CONFIG: $BUILDROOT_CONFIG"
KERNEL_CONFIG="$KERNEL_BUILD_DIR/.config"
print_debug "KERNEL_CONFIG: $KERNEL_CONFIG"
CHANGES_DOC="$SCRIPT_DIR/CHANGES_DOCUMENTATION.md"
print_debug "CHANGES_DOC: $CHANGES_DOC"


SOURCE_DTS="$SCRIPT_DIR/lan966x-pcb8291.dts"
print_debug "SOURCE_DTS: $SOURCE_DTS"
SOURCE_LAN865X="$SCRIPT_DIR/lan865x.c"
print_debug "SOURCE_LAN865X: $SOURCE_LAN865X"
SOURCE_MICROCHIP_T1S="$SCRIPT_DIR/microchip_t1s.c"
print_debug "SOURCE_MICROCHIP_T1S: $SOURCE_MICROCHIP_T1S"
LINUX_CONFIG_SOURCE="$SCRIPT_DIR/linux.config"
print_debug "LINUX_CONFIG_SOURCE: $LINUX_CONFIG_SOURCE"
BUILDROOT_CONFIG_SOURCE="$SCRIPT_DIR/buildroot.config"
print_debug "BUILDROOT_CONFIG_SOURCE: $BUILDROOT_CONFIG_SOURCE"
TARGET_DTB="lan966x-pcb8291.dtb"
print_debug "TARGET_DTB: $TARGET_DTB"


## 2. Copy custom configuration files: already set correctly above
LINUX_CONFIG_TARGET="$KERNEL_BUILD_DIR/.config"
BUILDROOT_CONFIG_TARGET="$OUTPUT_DIR/.config"

if [[ -f "$LINUX_CONFIG_SOURCE" ]]; then
    cp "$LINUX_CONFIG_SOURCE" "$LINUX_CONFIG_TARGET"
    print_info "Custom Linux kernel configuration copied."
else
    print_warning "Custom Linux kernel configuration ($LINUX_CONFIG_SOURCE) not found!"
fi

if [[ -f "$BUILDROOT_CONFIG_SOURCE" ]]; then
    cp "$BUILDROOT_CONFIG_SOURCE" "$BUILDROOT_CONFIG_TARGET"
    print_info "Custom Buildroot configuration copied."
else
    print_warning "Custom Buildroot configuration ($BUILDROOT_CONFIG_SOURCE) not found!"
fi

# 3. Directory and file checks
[[ -f "$SOURCE_DTS" ]]      || print_error "SOURCE_DTS $SOURCE_DTS is missing!"
[[ -f "$SOURCE_LAN865X" ]]  || print_error "SOURCE_LAN865X $SOURCE_LAN865X is missing!"
[[ -f "$SOURCE_MICROCHIP_T1S" ]] || print_error "SOURCE_MICROCHIP_T1S $SOURCE_MICROCHIP_T1S is missing!"
[[ -f "$BUILDROOT_CONFIG_SOURCE" ]] || print_error "BUILDROOT_CONFIG_SOURCE $BUILDROOT_CONFIG_SOURCE is missing!"
[[ -f "$LINUX_CONFIG_SOURCE" ]]    || print_error "LINUX_CONFIG_SOURCE $LINUX_CONFIG_SOURCE is missing!"
[[ -d "$TARGET_DTS_DIR" ]]  || print_error "TARGET_DTS_DIR $TARGET_DTS_DIR is missing!"
[[ -d "$BUILD_DIR" ]]       || print_error "BUILD_DIR $BUILD_DIR is missing!"
[[ -d "$KERNEL_BUILD_DIR" ]]|| print_error "KERNEL_BUILD_DIR $KERNEL_BUILD_DIR is missing!"
[[ -d "$IMAGES_DIR" ]]      || print_error "IMAGES_DIR $IMAGES_DIR is missing!"

print_info "Directory and file checks successful."

# 4. Copy device tree and remove old DTBs
cp "$SOURCE_DTS" "$TARGET_DTS_DIR/"
rm -f "$TARGET_DTS_DIR/$TARGET_DTB" "$IMAGES_DIR/$TARGET_DTB"
print_info "Device tree copied and old DTBs removed."



# 5. Erzeuge und prüfe Overlay-Dateien ausschließlich im Quell-Overlay
if [[ -d "$OVERLAY_SRC" ]]; then
    # Set Dropbear configuration for development (im Quell-Overlay)
    DROPBEAR_CONF_PATH="$OVERLAY_SRC/etc/dropbear/dropbear.conf"
    mkdir -p "$(dirname "$DROPBEAR_CONF_PATH")"
    echo "# Dropbear SSH configuration for LAN8651 development" > "$DROPBEAR_CONF_PATH"
    echo "# Allows root login and password authentication for development purposes" >> "$DROPBEAR_CONF_PATH"
    echo "" >> "$DROPBEAR_CONF_PATH"
    echo "# Enable root login and password authentication" >> "$DROPBEAR_CONF_PATH"
    echo "DROPBEAR_ARGS=\"\"" >> "$DROPBEAR_CONF_PATH"
    print_info "Dropbear configuration for development set: $DROPBEAR_CONF_PATH"
else
    print_warning "Overlay source $OVERLAY_SRC not found!"
fi

# 6. Update kernel driver file
LAN865X_TARGET="$KERNEL_BUILD_DIR/drivers/net/ethernet/microchip/lan865x/lan865x.c"
cp "$SOURCE_LAN865X" "$LAN865X_TARGET"
print_info "LAN865x driver file updated."
MICROCHIP_T1S_TARGET="$KERNEL_BUILD_DIR/drivers/net/phy/microchip_t1s.c"                                       
cp "$SOURCE_MICROCHIP_T1S" "$MICROCHIP_T1S_TARGET"
print_info "Microchip T1S driver file updated."

# 7. Set up Ethernet interfaces (via overlay)
# 7. Set up Ethernet interfaces (via overlay, directly in the source overlay)
ETH_OVERLAY_SRC="$BASE_DIR/board/mscc/common/rootfs_overlay/etc/network/interfaces"
mkdir -p "$(dirname "$ETH_OVERLAY_SRC")"
cat > "$ETH_OVERLAY_SRC" <<EOF
auto eth0
iface eth0 inet static
    address 169.254.45.100
    netmask 255.255.0.0

auto eth1
iface eth1 inet static
    address 192.168.0.5
    netmask 255.255.255.0

auto eth2
iface eth2 inet static
    address 169.254.45.150
    netmask 255.255.0.0
EOF

print_info "Ethernet interfaces set up in source overlay: $ETH_OVERLAY_SRC"


# 7.1. Create init script for lan865x module autoload (BusyBox init workaround) in the source overlay
INITD_SCRIPT_SRC="$BASE_DIR/board/mscc/common/rootfs_overlay/etc/init.d/S09lan865xmodprobe"
mkdir -p "$(dirname "$INITD_SCRIPT_SRC")"
cat > "$INITD_SCRIPT_SRC" <<'EOS'
#!/bin/sh
# Startup script for lan865x kernel module (BusyBox init compatible)
### BEGIN INIT INFO
# Provides:          lan865xmodprobe
# Required-Start:    $all
# Required-Stop:
# Default-Start:     S
# Default-Stop:
# Short-Description: Load lan865x kernel module at boot
### END INIT INFO

case "$1" in
    start|default)
        if ! lsmod | grep -q '^lan865x'; then
            echo "[lan865xmodprobe] Loading lan865x kernel module..."
            modprobe lan865x && echo "[lan865xmodprobe] lan865x loaded." || echo "[lan865xmodprobe] Error loading lan865x!"
        else
            echo "[lan865xmodprobe] lan865x already loaded."
        fi
        ;;
    stop)
        if lsmod | grep -q '^lan865x'; then
            echo "[lan865xmodprobe] Unloading lan865x kernel module..."
            modprobe -r lan865x || rmmod lan865x || true
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|default}"
        exit 1
        ;;
esac
exit 0
EOS
chmod +x "$INITD_SCRIPT_SRC"
print_info "Init script for lan865x module autoload created: $INITD_SCRIPT_SRC"

# 8. Create load script for the target in the source overlay
LOAD_SCRIPT_SRC="$BASE_DIR/board/mscc/common/rootfs_overlay/root/load_lan865x.sh"
mkdir -p "$(dirname "$LOAD_SCRIPT_SRC")"
cat > "$LOAD_SCRIPT_SRC" <<'EOS'
#!/bin/sh
set -e
if lsmod | grep -q lan865x; then
    echo "Unloading old lan865x module..."
    modprobe -r lan865x || rmmod lan865x || true
fi
echo "Loading new lan865x module..."
modprobe lan865x && echo "lan865x loaded." || echo "Error loading lan865x!"
EOS
chmod +x "$LOAD_SCRIPT_SRC"
print_info "Load script $LOAD_SCRIPT_SRC created."

# 9. Kernel module autoload (overlay, nur im Quell-Overlay)
MODULES_LOAD="$OVERLAY_SRC/etc/modules-load.d/lan865x.conf"
mkdir -p "$(dirname "$MODULES_LOAD")"
echo "lan865x" > "$MODULES_LOAD"
print_info "Autoload for lan865x module set up: $MODULES_LOAD"

# 10. Run build
cd "$OUTPUT_DIR"
print_info "Starting build: make linux-reconfigure"
make linux-reconfigure || print_error "make linux-reconfigure failed!"
print_info "Starting build: make"
make || print_error "make failed!"


# 10.1. DTB check
DTB_PATH="$OUTPUT_DIR/images/$TARGET_DTB"
print_info "Working Directory: $(pwd)"
print_info "Check DTB_PATH: $DTB_PATH"
if [[ ! -f "$DTB_PATH" ]]; then
    print_error "New DTB $DTB_PATH not found!"
fi
print_info "New DTB found."

# 10.2. dtc check
print_info "Prüfe mit dtc: $DTB_PATH"
if ! dtc -I dtb -O dts -o - "$DTB_PATH" | grep -a -q 'microchip,lan8651'; then
    print_error "DTB does not contain 'microchip,lan8651'!"
fi
print_info "DTB contains 'microchip,lan8651'."

cd "$SCRIPT_DIR"
print_info "Working Directory: $(pwd)"
    # ...existing code...

# 10.6. Kernelmodule-Autoload-Check (absolute path)
print_info "Check Autoload: $MODULES_LOAD"
if [[ -f "$MODULES_LOAD" ]]; then
    print_info "Autoload-Entry lan865x available."
else
    print_warning "No Autoload-Entry found for lan865x!"
fi


LAN865X_KO_SRC="$OUTPUT_DIR/build/linux-custom/drivers/net/ethernet/microchip/lan865x/lan865x.ko"
LAN865X_KO_DST="/mnt/c/Users/M91221/work/lan9662/lan865x.ko"
if [[ -f "$LAN865X_KO_SRC" ]]; then
    cp "$LAN865X_KO_SRC" "$LAN865X_KO_DST"
    print_info "lan865x.ko was copied to $LAN865X_KO_DST."
else
    print_warning "lan865x.ko not found: $LAN865X_KO_SRC"
fi

# Teste am Ende, ob die wichtigen Overlay-Dateien vorhanden sind
DROPBEAR_CONF_OVERLAY="$BASE_DIR/board/mscc/common/rootfs_overlay/etc/dropbear/dropbear.conf"
LAN865X_CONF_OVERLAY="$BASE_DIR/board/mscc/common/rootfs_overlay/etc/modules-load.d/lan865x.conf"

if [ -f "$DROPBEAR_CONF_OVERLAY" ]; then
    print_info "dropbear.conf ist im Overlay vorhanden: $DROPBEAR_CONF_OVERLAY"
else
    print_warning "dropbear.conf fehlt im Overlay: $DROPBEAR_CONF_OVERLAY"
fi

if [ -f "$LAN865X_CONF_OVERLAY" ]; then
    print_info "lan865x.conf ist im Overlay vorhanden: $LAN865X_CONF_OVERLAY"
else
    print_warning "lan865x.conf fehlt im Overlay: $LAN865X_CONF_OVERLAY"
fi

# Copy brsdk_standalone_arm.ext4.gz to the same destination directory
BRSKD_IMAGE_SRC="/home/martin/AIoT/work/mchp-brsdk-source-2025.12/output/mybuild/images/brsdk_standalone_arm.ext4.gz"
BRSKD_IMAGE_DST="/mnt/c/Users/M91221/work/lan9662/brsdk_standalone_arm.ext4.gz"
if [[ -f "$BRSKD_IMAGE_SRC" ]]; then
    cp "$BRSKD_IMAGE_SRC" "$BRSKD_IMAGE_DST"
    print_info "brsdk_standalone_arm.ext4.gz was copied to $BRSKD_IMAGE_DST."
else
    print_warning "brsdk_standalone_arm.ext4.gz not found: $BRSKD_IMAGE_SRC"
fi

print_info "Patch script completed successfully. The build is now prepared for LAN8651 development."
