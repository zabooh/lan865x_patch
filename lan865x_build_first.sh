#!/bin/bash
#!/bin/bash
# 1. Initialization and helper functions

set -euo pipefail


BSP_VERSION="mchp-brsdk-source-2025.12.tar.gz"
MY_CONFIG="mybuild"


## Colored output
print_info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
print_warning() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
print_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# Startverzeichnis sichern


# 2. Save start directory
REPO_DIR="$(pwd)"
trap 'cd "$REPO_DIR"' EXIT



print_info "Starting script in: $REPO_DIR"
print_info "BSP version: $BSP_VERSION"


# -----------------------------------------------------------
# 1. BSP herunterladen
# -----------------------------------------------------------

# 3. Download BSP archive (only if not present)
if [[ -f "$BSP_VERSION" ]]; then
    print_info "BSP archive already present: $BSP_VERSION – skipping download."
else
    print_info "Downloading LAN9662 Board Support Package..."
    BSP_URL="http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/bsp/$BSP_VERSION"
    if ! wget --progress=bar:force "$BSP_URL"; then
        print_error "Download failed: $BSP_URL"
        exit 1
    fi
    if [[ ! -f "$BSP_VERSION" ]]; then
        print_error "Downloaded file '$BSP_VERSION' not found!"
        exit 1
    fi
    echo "Download successful: $BSP_VERSION"
fi


# --- Prüfung: existiert das BSP-Archiv? ----------------------

# 4. Check: does the BSP archive exist?
if [[ ! -f "$BSP_VERSION" ]]; then
    print_error "BSP file '$BSP_VERSION' not found!"
    exit 1
fi

# --- Kopieren des Archivs ------------------------------------

# 5. Copy BSP archive to parent directory (only if not present)
if [[ -f "../$BSP_VERSION" ]]; then
    print_info "BSP archive already present in parent directory: ../$BSP_VERSION – skipping copy."
else
    print_info "Copying BSP archive to parent directory..."
    cp "$BSP_VERSION" ./..
fi


# 6. Change working directory to parent directory
cd ..

# --- Archiv entpacken ----------------------------------------

# --- Verzeichnis ermitteln ------------------------------------

# 7. Determine name of extracted BSP directory
BSP_DIR="${BSP_VERSION%.tar.gz}"


# 8. Extract BSP archive (only if not already extracted)
if [[ -d "$BSP_DIR" ]]; then
    print_info "BSP directory already extracted: $BSP_DIR – skipping extraction."
else
    print_info "Extracting BSP: $BSP_VERSION"
    if ! tar -xvzf "$BSP_VERSION"; then
        print_error "Error extracting $BSP_VERSION"
        exit 1
    fi
fi


# 9. Check: was the BSP directory extracted correctly?
if [[ ! -d "$BSP_DIR" ]]; then
    print_error "After extraction, directory '$BSP_DIR' not found!"
    exit 1
fi



print_info "BSP successfully extracted: $BSP_DIR"

# --- Build starten --------------------------------------------


# 10. Change into BSP directory
cd "$BSP_DIR"

# --- Kopiere linux.config an die erwarteten Stellen ---
if [[ -f "$REPO_DIR/linux.config" ]]; then
    cp "$REPO_DIR/linux.config" "board/microchip/standalone/arm_kernel.config"
    print_info "linux.config wurde nach board/microchip/standalone/arm_kernel.config kopiert."
    cp "$REPO_DIR/linux.config" ./linux.config
    print_info "linux.config wurde zusätzlich ins BSP-Hauptverzeichnis kopiert."
else
    print_warning "linux.config nicht im Startverzeichnis gefunden!"
fi


# 11. Generate Buildroot configuration (defconfig, only if not present)
if [[ -d "./output/$MY_CONFIG" ]]; then
    print_info "Build output directory ./output/$MY_CONFIG already exists – skipping 'make ... defconfig'."
else
    print_info "Running 'make ... defconfig'"
    if ! make BR2_EXTERNAL=./external O=./output/$MY_CONFIG arm_standalone_defconfig; then
        print_error "make defconfig failed!"
        exit 1
    fi
fi

# 12. Check: is build output directory present?
if [[ ! -d "./output/$MY_CONFIG" ]]; then
    print_error "Build output directory './output/$MY_CONFIG' was not created!"
    exit 1
fi

# 13. Change into build output directory
cd "./output/$MY_CONFIG"

# 14. Run build (only if images do not already exist)
if [[ -d "./images" ]]; then
    print_info "Image folder ./images already exists – skipping build."
else
    print_info "Starting build (make)"
    if ! make; then
        print_error "make build failed!"
        exit 1
    fi
    print_info "Build completed successfully."
fi

# --- Zurück zu REPO_DIR und Patch anwenden ------------------------

# 15. Change back to original repository directory
cd "$REPO_DIR"
print_info "Now applying the patch from $REPO_DIR"

# 16. Check: is patch script present and executable?
if [[ ! -x "./patch_bsp_lan8651.sh" ]]; then
    print_error "Patch script 'patch_bsp_lan8651.sh' not found or not executable!"
    exit 1
fi

# 17. Run patch script
print_info "Starting patch script"
./patch_bsp_lan8651.sh "$MY_CONFIG" "$BSP_DIR" $REPO_DIR

print_info "Script completed successfully."

