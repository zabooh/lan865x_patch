#!/bin/bash
# 1. Initialisierung und Hilfsfunktionen
set -euo pipefail


BSP_VERSION="mchp-brsdk-source-2025.12.tar.gz"
MY_CONFIG="mybuild"

## Farbige Ausgaben
print_info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
print_warning() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
print_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# Startverzeichnis sichern

# 2. Startverzeichnis sichern
REPO_DIR="$(pwd)"
trap 'cd "$REPO_DIR"' EXIT


print_info "Starte Skript in: $REPO_DIR"
print_info "BSP Version: $BSP_VERSION"


# -----------------------------------------------------------
# 1. BSP herunterladen
# -----------------------------------------------------------

# 3. BSP-Archiv herunterladen (nur falls nicht vorhanden)
if [[ -f "$BSP_VERSION" ]]; then
    print_info "BSP-Archiv bereits vorhanden: $BSP_VERSION – Download wird übersprungen."
else
    print_info "Lade LAN9662 Board Support Package herunter..."
    BSP_URL="http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/bsp/$BSP_VERSION"
    if ! wget --progress=bar:force "$BSP_URL"; then
        print_error "Download fehlgeschlagen: $BSP_URL"
        exit 1
    fi
    if [[ ! -f "$BSP_VERSION" ]]; then
        print_error "Heruntergeladene Datei '$BSP_VERSION' wurde nicht gefunden!"
        exit 1
    fi
    echo "Download erfolgreich: $BSP_VERSION"
fi


# --- Prüfung: existiert das BSP-Archiv? ----------------------

# 4. Prüfung: existiert das BSP-Archiv?
if [[ ! -f "$BSP_VERSION" ]]; then
    print_error "BSP-Datei '$BSP_VERSION' nicht gefunden!"
    exit 1
fi

# --- Kopieren des Archivs ------------------------------------

# 5. BSP-Archiv ins Parent-Verzeichnis kopieren (nur falls nicht vorhanden)
if [[ -f "../$BSP_VERSION" ]]; then
    print_info "BSP-Archiv ist im Parent-Verzeichnis bereits vorhanden: ../$BSP_VERSION – Kopieren wird übersprungen."
else
    print_info "Kopiere BSP-Archiv nach .."
    cp "$BSP_VERSION" ./..
fi


# 6. Arbeitsverzeichnis ins Parent-Verzeichnis wechseln
cd ..

# --- Archiv entpacken ----------------------------------------

# --- Verzeichnis ermitteln ------------------------------------

# 7. Name des entpackten BSP-Verzeichnisses bestimmen
BSP_DIR="${BSP_VERSION%.tar.gz}"


# 8. BSP-Archiv entpacken (nur falls nicht bereits entpackt)
if [[ -d "$BSP_DIR" ]]; then
    print_info "BSP-Verzeichnis bereits entpackt: $BSP_DIR – Entpacken wird übersprungen."
else
    print_info "Entpacke BSP: $BSP_VERSION"
    if ! tar -xvzf "$BSP_VERSION"; then
        print_error "Fehler beim Entpacken von $BSP_VERSION"
        exit 1
    fi
fi


# 9. Prüfung: Wurde das BSP-Verzeichnis korrekt entpackt?
if [[ ! -d "$BSP_DIR" ]]; then
    print_error "Nach dem Entpacken wurde das Verzeichnis '$BSP_DIR' nicht gefunden!"
    exit 1
fi


print_info "BSP erfolgreich extrahiert: $BSP_DIR"

# --- Build starten --------------------------------------------

# 10. In das BSP-Verzeichnis wechseln
cd "$BSP_DIR"


# 11. Buildroot-Konfiguration erzeugen (defconfig, nur falls nicht vorhanden)
if [[ -d "./output/$MY_CONFIG" ]]; then
    print_info "Build-Output-Verzeichnis ./output/$MY_CONFIG ist bereits vorhanden – 'make ... defconfig' wird übersprungen."
else
    print_info "Führe 'make ... defconfig' aus"
    if ! make BR2_EXTERNAL=./external O=./output/$MY_CONFIG arm_standalone_defconfig; then
        print_error "make defconfig fehlgeschlagen!"
        exit 1
    fi
fi

# 12. Prüfung: Build-Output-Verzeichnis vorhanden?
if [[ ! -d "./output/$MY_CONFIG" ]]; then
    print_error "Build-Output-Verzeichnis './output/$MY_CONFIG' wurde nicht erzeugt!"
    exit 1
fi

# 13. In das Build-Output-Verzeichnis wechseln
cd "./output/$MY_CONFIG"

# 14. Build ausführen (nur falls Images noch nicht existieren)
if [[ -d "./images" ]]; then
    print_info "Image-Ordner ./images ist bereits vorhanden – Build wird übersprungen."
else
    print_info "Starte Build (make)"
    if ! make; then
        print_error "make build fehlgeschlagen!"
        exit 1
    fi
    print_info "Build erfolgreich abgeschlossen."
fi

# --- Zurück zu REPO_DIR und Patch anwenden ------------------------

# 15. Zurück ins ursprüngliche Repository-Verzeichnis wechseln
cd "$REPO_DIR"
print_info "Jetzt wird der Patch angewendet von $REPO_DIR aus "

# 16. Prüfung: Patch-Skript vorhanden und ausführbar?
if [[ ! -x "./patch_bsp_lan8651.sh" ]]; then
    print_error "Patch-Skript 'patch_bsp_lan8651.sh' nicht gefunden oder nicht ausführbar!"
    exit 1
fi

# 17. Patch-Skript ausführen
print_info "Starte Patch-Skript"
./patch_bsp_lan8651.sh "$MY_CONFIG" "$BSP_DIR" $REPO_DIR

print_info "Skript erfolgreich abgeschlossen."

