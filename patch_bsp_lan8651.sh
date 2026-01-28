#!/usr/bin/env bash

## Farbige Ausgaben
print_info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
print_warning() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
print_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }


print_info "# Änderungen für LAN8651-Entwicklung"
print_info ""
print_info "Dieses Dokument fasst die vorgenommenen Änderungen und Anpassungen für die Entwicklung mit dem LAN8651 Ethernet-Controller zusammen."
print_info ""
print_info "## Änderungen im Build-Prozess"
print_info "- Erzeugung und Anpassung von \`post-build.sh\` zur Konfiguration von SSH-Zugang und Root-Passwort."
print_info "- Kopieren eigener Kernel- und Buildroot-Konfigurationsdateien."
print_info "- Aktualisierung des Device Trees mit Unterstützung für LAN8651."
print_info "- Einrichtung eines RootFS-Overlays mit spezifischen Anpassungen für Dropbear SSH und Netzwerkinterfaces."
print_info "- Aktualisierung des LAN865x Kernel-Treibers."
print_info "- Einrichtung eines Init-Skripts für das automatische Laden des LAN865x Moduls beim Systemstart."
print_info "- Erstellung eines Ladeskripts für das manuelle Laden des LAN865x Moduls auf dem Target-System."
print_info ""
print_info "## Wichtige Dateien"
print_info "- \`post-build.sh\`: Konfiguriert SSH-Zugang und Root-Passwort."
print_info "- \`lan966x-pcb8291.dts\`: Device Tree Source Datei mit LAN8651 Unterstützung."
print_info "- \`lan865x.c\`: Aktualisierte Kernel-Treiberdatei für den LAN865x Ethernet-Controller."
print_info "- \`load_lan865x.sh\`: Skript zum Laden des LAN865x Kernelmoduls auf dem Target."
print_info "- \`S09lan865xmodprobe\`: Init-Skript zum automatischen Laden des LAN865x Moduls beim Booten."
print_info ""
print_info "## Hinweise"
print_info "- Der Root-Benutzer ist standardmäßig mit dem Passwort 'microchip' konfiguriert. Es wird empfohlen, dieses Passwort nach der Entwicklung zu ändern."
print_info "- Stellen Sie sicher, dass die Dropbear SSH-Konfiguration den Sicherheitsanforderungen Ihrer Umgebung entspricht."


print_info "Dieses Skript führt folgende Schritte aus:"
print_info " 1. post-build.sh erzeugen, falls nicht vorhanden"
print_info " 2. Eigene Konfigurationsdateien kopieren (Kernel/Buildroot)"
print_info " 3. Verzeichnis- und Dateiprüfungen"
print_info " 4. Device Tree kopieren und alte DTBs entfernen"
print_info " 5. Overlay kopieren und konfigurieren (Dropbear, Netzwerk)"
print_info " 6. Kernel-Treiberdatei aktualisieren (lan865x.c)"
print_info " 7. Ethernet-Schnittstellen im Overlay einrichten"
print_info " 8. Ladeskript für das Target erzeugen"
print_info " 9. Kernelmodul-Autoload (Overlay) einrichten"
print_info "10. Build ausführen (make linux-reconfigure, make)"
print_info "11. Prüfungen (DTB, Overlay, Dropbear, Autoload)"
print_info "12. Dokumentation der Änderungen"
print_info "Folgende Dateien und Verzeichnisse werden vorausgesetzt:"
print_info " - lan966x-pcb8291.dts"
print_info " - lan865x.c"
print_info " - linux.config"
print_info " - buildroot.config"
print_info " - board/mscc/common/rootfs_overlay/ (mit Inhalt)"
print_info " - output/${1}/build/linux-custom/arch/arm/boot/dts/microchip/ (Ziel für DTS/DTB)"
print_info " - output/${1}/build/ (Buildverzeichnis)"
print_info " - output/${1}/build/linux-custom/ (Kernel-Buildverzeichnis)"
print_info " - output/${1}/images/ (Imageverzeichnis)"
print_info "Bitte bestätigen Sie mit 'y' und Enter, um fortzufahren, oder brechen Sie mit 'n' ab."
read -r -p "Fortfahren? [y/n]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_info "Abbruch durch Benutzer."
    exit 1
fi

# 1. post-build.sh erzeugen, falls nicht vorhanden
POST_BUILD_SH="./board/mscc/common/post-build.sh"
if [[ ! -f "$POST_BUILD_SH" ]]; then
    mkdir -p "$(dirname "$POST_BUILD_SH")"
    cat > "$POST_BUILD_SH" <<'EOSH'
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

# Create dropbear config directory if it doesn't exist
mkdir -p "$TARGET_DIR/etc/dropbear"

# Ensure proper permissions
chmod 755 "$TARGET_DIR/etc/dropbear"
chmod 600 "$TARGET_DIR/etc/shadow" 2>/dev/null

echo "SSH configuration completed."
echo "Root login enabled with password: microchip"
EOSH
    chmod +x "$POST_BUILD_SH"
    print_info "post-build.sh wurde automatisch erzeugt."
fi
#!/usr/bin/env bash
set -euo pipefail


# 1. Initialisierung und Parameterprüfung
if [[ $# -ne 1 ]]; then
    print_error "Genau ein Argument (Build-Konfigurationsverzeichnis) erforderlich!"
fi
BUILD_CONFIG="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
BASE_DIR="."
OUTPUT_DIR="./output/$BUILD_CONFIG"
BUILD_DIR="$OUTPUT_DIR/build"
KERNEL_BUILD_DIR="$BUILD_DIR/linux-custom"
TARGET_DTS_DIR="$KERNEL_BUILD_DIR/arch/arm/boot/dts/microchip"
IMAGES_DIR="$OUTPUT_DIR/images"
SOURCE_DTS="./lan966x-pcb8291.dts"
SOURCE_LAN865X="./lan865x.c"
TARGET_DTB="lan966x-pcb8291.dtb"
OVERLAY_SRC="./board/mscc/common/rootfs_overlay"
OVERLAY_DST="$OUTPUT_DIR/board/mscc/common/rootfs_overlay"
 BUILDROOT_CONFIG="$OUTPUT_DIR/.config"
KERNEL_CONFIG="$KERNEL_BUILD_DIR/.config"
CHANGES_DOC="./CHANGES_DOCUMENTATION.md"



# 2. Eigene Konfigurationsdateien kopieren
LINUX_CONFIG_SOURCE="./linux.config"
BUILDROOT_CONFIG_SOURCE="./buildroot.config"
LINUX_CONFIG_TARGET="$KERNEL_BUILD_DIR/.config"
BUILDROOT_CONFIG_TARGET="$OUTPUT_DIR/.config"

if [[ -f "$LINUX_CONFIG_SOURCE" ]]; then
    cp "$LINUX_CONFIG_SOURCE" "$LINUX_CONFIG_TARGET"
    print_info "Eigene Linux-Kernel-Konfiguration kopiert."
else
    print_warning "Eigene Linux-Kernel-Konfiguration ($LINUX_CONFIG_SOURCE) nicht gefunden!"
fi

if [[ -f "$BUILDROOT_CONFIG_SOURCE" ]]; then
    cp "$BUILDROOT_CONFIG_SOURCE" "$BUILDROOT_CONFIG_TARGET"
    print_info "Eigene Buildroot-Konfiguration kopiert."
else
    print_warning "Eigene Buildroot-Konfiguration ($BUILDROOT_CONFIG_SOURCE) nicht gefunden!"
fi

# 3. Verzeichnis- und Dateiprüfungen
[[ -f "$SOURCE_DTS" ]]      || print_error "SOURCE_DTS $SOURCE_DTS fehlt!"
[[ -f "$SOURCE_LAN865X" ]]  || print_error "SOURCE_LAN865X $SOURCE_LAN865X fehlt!"
[[ -d "$TARGET_DTS_DIR" ]]  || print_error "TARGET_DTS_DIR $TARGET_DTS_DIR fehlt!"
[[ -d "$BUILD_DIR" ]]       || print_error "BUILD_DIR $BUILD_DIR fehlt!"
[[ -d "$KERNEL_BUILD_DIR" ]]|| print_error "KERNEL_BUILD_DIR $KERNEL_BUILD_DIR fehlt!"
[[ -d "$IMAGES_DIR" ]]      || print_error "IMAGES_DIR $IMAGES_DIR fehlt!"

print_info "Verzeichnis- und Dateiprüfungen erfolgreich."

# 4. Device Tree kopieren und alte DTBs entfernen
cp "$SOURCE_DTS" "$TARGET_DTS_DIR/"
rm -f "$TARGET_DTS_DIR/$TARGET_DTB" "$IMAGES_DIR/$TARGET_DTB"
print_info "Device Tree kopiert und alte DTBs entfernt."



# 5. Overlay kopieren und prüfen
if [[ -d "$OVERLAY_SRC" ]]; then
    mkdir -p "$(dirname "$OVERLAY_DST")"
    rm -rf "$OVERLAY_DST"
    cp -a "$OVERLAY_SRC" "$OVERLAY_DST"
    print_info "Overlay kopiert (Ziel vorher gelöscht)."
    # Prüfungen werden am Ende des Skripts ausgeführt

    # Dropbear-Konfiguration für Entwicklung setzen
    DROPBEAR_CONF_PATH="$OVERLAY_DST/etc/dropbear/dropbear.conf"
    mkdir -p "$(dirname "$DROPBEAR_CONF_PATH")"
    echo "# Dropbear SSH configuration for LAN8651 development" > "$DROPBEAR_CONF_PATH"
    echo "# Allows root login and password authentication for development purposes" >> "$DROPBEAR_CONF_PATH"
    echo "" >> "$DROPBEAR_CONF_PATH"
    echo "# Enable root login and password authentication" >> "$DROPBEAR_CONF_PATH"
    echo "DROPBEAR_ARGS=\"\"" >> "$DROPBEAR_CONF_PATH"
    print_info "Dropbear-Konfiguration für Entwicklung gesetzt: $DROPBEAR_CONF_PATH"
else
    print_warning "Overlay-Quelle $OVERLAY_SRC nicht gefunden!"
fi

# 6. Kernel-Treiberdatei aktualisieren
LAN865X_TARGET="$KERNEL_BUILD_DIR/drivers/net/ethernet/microchip/lan865x/lan865x.c"
cp "$SOURCE_LAN865X" "$LAN865X_TARGET"
print_info "LAN865x-Treiberdatei aktualisiert."

# 7. Ethernet-Schnittstellen einrichten (per Overlay)
# 7. Ethernet-Schnittstellen einrichten (per Overlay, direkt im Quell-Overlay)
ETH_OVERLAY_SRC="./board/mscc/common/rootfs_overlay/etc/network/interfaces"
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

print_info "Ethernet-Interfaces im Quell-Overlay eingerichtet: $ETH_OVERLAY_SRC"


# 7.1. Init-Skript für lan865x-Modul-Autoload (BusyBox init workaround) im Quell-Overlay erzeugen
INITD_SCRIPT_SRC="./board/mscc/common/rootfs_overlay/etc/init.d/S09lan865xmodprobe"
mkdir -p "$(dirname "$INITD_SCRIPT_SRC")"
cat > "$INITD_SCRIPT_SRC" <<'EOS'
#!/bin/sh
# Startscript für lan865x Kernelmodul (BusyBox init-kompatibel)
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
            echo "[lan865xmodprobe] Lade lan865x Kernelmodul..."
            modprobe lan865x && echo "[lan865xmodprobe] lan865x geladen." || echo "[lan865xmodprobe] Fehler beim Laden von lan865x!"
        else
            echo "[lan865xmodprobe] lan865x bereits geladen."
        fi
        ;;
    stop)
        if lsmod | grep -q '^lan865x'; then
            echo "[lan865xmodprobe] Entlade lan865x Kernelmodul..."
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
print_info "Init-Skript für lan865x-Modul-Autoload erzeugt: $INITD_SCRIPT_SRC"

# 8. Ladeskript für das Target im Quell-Overlay erzeugen
LOAD_SCRIPT_SRC="./board/mscc/common/rootfs_overlay/root/load_lan865x.sh"
mkdir -p "$(dirname "$LOAD_SCRIPT_SRC")"
cat > "$LOAD_SCRIPT_SRC" <<'EOS'
#!/bin/sh
set -e
if lsmod | grep -q lan865x; then
    echo "Entlade altes lan865x-Modul..."
    modprobe -r lan865x || rmmod lan865x || true
fi
echo "Lade neues lan865x-Modul..."
modprobe lan865x && echo "lan865x geladen." || echo "Fehler beim Laden von lan865x!"
EOS
chmod +x "$LOAD_SCRIPT_SRC"
print_info "Ladeskript $LOAD_SCRIPT_SRC erzeugt."

# 9. Kernelmodul-Autoload (Overlay)
MODULES_LOAD="$OVERLAY_DST/etc/modules-load.d/lan865x.conf"
mkdir -p "$(dirname "$MODULES_LOAD")"
LAN865X_CONF_PATH="./output/${BUILD_CONFIG}/board/mscc/common/rootfs_overlay/etc/modules-load.d/lan865x.conf"
echo "lan865x" > "$LAN865X_CONF_PATH"
echo "[INFO] Autoload für lan865x-Modul eingerichtet: $LAN865X_CONF_PATH"
echo "lan865x" > "$MODULES_LOAD"
print_info "Autoload für lan865x-Modul eingerichtet."

# 10. Build ausführen
cd "$OUTPUT_DIR"
print_info "Starte Build: make linux-reconfigure"
make linux-reconfigure || print_error "make linux-reconfigure fehlgeschlagen!"
print_info "Starte Build: make"
make || print_error "make fehlgeschlagen!"


# 10.1. DTB-Prüfung
DTB_PATH="$SCRIPT_DIR/output/$BUILD_CONFIG/images/$TARGET_DTB"
print_info "[DEBUG] Arbeitsverzeichnis: $(pwd)"
print_info "[DEBUG] Prüfe DTB_PATH: $DTB_PATH"
if [[ ! -f "$DTB_PATH" ]]; then
    print_error "Neue DTB $DTB_PATH nicht gefunden!"
fi
print_info "Neue DTB gefunden."

# 10.2. dtc-Prüfung
print_info "[DEBUG] Prüfe mit dtc: $DTB_PATH"
if ! dtc -I dtb -O dts -o - "$DTB_PATH" | grep -q 'microchip,lan8651'; then
    print_error "DTB enthält nicht 'microchip,lan8651'!"
fi
print_info "DTB enthält 'microchip,lan8651'."

cd "$SCRIPT_DIR"
print_info "[DEBUG] Arbeitsverzeichnis: $(pwd)"
echo PWD:::: 
pwd

# 10.3. SSH-Prüfung (nur dropbear.conf, absoluter Pfad)
DROPBEAR_CONF_ABS="$OVERLAY_DST/etc/dropbear/dropbear.conf"
print_info "[DEBUG] Prüfe DROPBEAR_CONF_ABS: $DROPBEAR_CONF_ABS"
if [[ -f "$DROPBEAR_CONF_ABS" ]]; then
    print_info "Dropbear-Konfiguration im Overlay vorhanden (absoluter Pfad)."
else
    print_warning "Dropbear-Konfiguration im Overlay fehlt (absoluter Pfad)!"
fi

# 10.4. Kernelmodul-Autoload-Prüfung
print_info "[DEBUG] Prüfe MODULES_LOAD_PATH: $OVERLAY_DST/etc/modules-load.d/lan865x.conf"
if grep -q 'lan865x' "$OVERLAY_DST/etc/modules-load.d/lan865x.conf"; then
    print_info "Autoload-Eintrag für lan865x vorhanden."
else
    print_warning "Kein Autoload-Eintrag für lan865x gefunden!"
fi

# 10.5. SSH-Prüfung (nur Overlay-Prüfung)
print_info "[DEBUG] Prüfe SSH-Konfiguration: $OVERLAY_DST/etc/default/dropbear und $OVERLAY_DST/etc/dropbear/dropbear.conf"
if [[ -f "$OVERLAY_DST/etc/default/dropbear" && -f "$OVERLAY_DST/etc/dropbear/dropbear.conf" ]]; then
    print_info "SSH-Konfiguration im Overlay vorhanden."
else
    print_warning "SSH-Konfiguration im Overlay unvollständig!"
fi

# 10.6. Kernelmodul-Autoload-Prüfung
print_info "[DEBUG] Prüfe Autoload: $MODULES_LOAD"
if grep -q 'lan865x' "$MODULES_LOAD"; then
    print_info "Autoload-Eintrag für lan865x vorhanden."
else
    print_warning "Kein Autoload-Eintrag für lan865x gefunden!"
fi


print_info "Patch-Skript erfolgreich abgeschlossen. Das Build ist jetzt für LAN8651-Entwicklung vorbereitet."

LAN865X_KO_SRC="./output/${BUILD_CONFIG}/build/linux-custom/drivers/net/ethernet/microchip/lan865x/lan865x.ko"
LAN865X_KO_DST="/mnt/c/Users/M91221/work/lan9662/lan865x.ko"
if [[ -f "$LAN865X_KO_SRC" ]]; then
    cp "$LAN865X_KO_SRC" "$LAN865X_KO_DST"
    print_info "lan865x.ko wurde nach $LAN865X_KO_DST kopiert."
else
    print_warning "lan865x.ko nicht gefunden: $LAN865X_KO_SRC"
fi

