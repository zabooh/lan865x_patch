# LAN865x Build First Script

The `lan865x_build_first.sh` script is the main entry point for setting up and building the LAN8651 development environment. It automates the following steps:

- Downloads and extracts the required Board Support Package (BSP) if not already present.
- Sets up the Buildroot configuration and runs the initial build process.
- After a successful build, it automatically calls the patch script (`patch_bsp_lan8651.sh`) to apply all necessary patches, configuration changes, and file copies for LAN8651 development.

This script ensures that the entire build and patch process is performed in the correct order, making it easy to get started with a single command.


# LAN8651 Buildroot Patch Script – English Documentation (2026-01-28)

## Required Source Files and Their Purpose

This patch script requires the following files and directories to be present in the project:

- **lan966x-pcb8291.dts**: Device Tree Source for the target board. Describes the hardware, especially the LAN865x node for SPI connection.
- **lan865x.c**: LAN865x driver source code. Integrated into the kernel build and built as a module.
- **linux.config**: Kernel configuration file. Specifies which kernel options and drivers are enabled during the build.
- **buildroot.config**: Buildroot configuration file. Determines which packages and settings are used for the root filesystem and toolchain.
- **board/mscc/common/rootfs_overlay/**: Overlay directory with additional files for the root filesystem (e.g., network config, SSH, init scripts). All contents are copied into the target rootfs.
- **output/<build_config>/build/linux-custom/arch/arm/boot/dts/microchip/**: Target directory for device tree files in the kernel build.
- **output/<build_config>/build/**: Build directory for all kernel and package sources.
- **output/<build_config>/build/linux-custom/**: Kernel build directory with all kernel sources and artifacts.
- **output/<build_config>/images/**: Directory for generated images (kernel, rootfs, DTB, etc.).

These files and directories are mandatory for the script to run successfully. If any are missing, the script will abort with an error message.

## Network Configuration (Overlay)

The patch script generates `/etc/network/interfaces` in the overlay with the following static network configuration:

- **eth0**: 169.254.45.100/16
- **eth1**: 192.168.0.5/24
- **eth2**: 169.254.45.150/16

These settings ensure all three interfaces are available with their respective addresses immediately after boot. The configuration is stored in `/etc/network/interfaces` in the rootfs and applied automatically at system startup.

## patch_bsp_lan8651.sh – Script Overview

This script automates the preparation and patching of a Buildroot environment for development with the Microchip LAN8651 module on a LAN9662 platform. It performs all necessary steps to correctly integrate and configure kernel, device tree, overlays, and development tools.

### Steps, Goals, and File Details

1. **Create post-build.sh if not present**
   - **Goal:** Automatically set up SSH access for the target system after the build, allowing developers to log in as root. The script sets the root password and enables Dropbear SSH.
   - **File:** Bash script that sets the root password in /etc/shadow to "microchip", enables Dropbear, and sets correct permissions for /etc/dropbear and /etc/shadow.

2. **Copy custom configuration files**
   - **Goal:** Ensure the desired kernel and Buildroot configurations are used for a reproducible and customized build environment.
   - **Files:**
     - `linux.config`: All kernel configuration options.
     - `buildroot.config`: All Buildroot configuration options.

3. **Directory and file checks**
   - **Goal:** Check for all required files and directories before starting the patch and build process to catch errors early.
   - **Files:** No new files, only checks.

4. **Copy device tree and remove old DTBs**
   - **Goal:** Integrate the current, customized device tree source into the build system and remove old, possibly incorrect DTBs.
   - **Files:**
     - `lan966x-pcb8291.dts`: Device tree source with all hardware definitions.
     - Removed files: old .dtb files in the build and images directories.

5. **Copy and configure overlay**
   - **Goal:** Integrate development-specific adjustments (e.g., SSH, network config) into the root filesystem so the target is ready to use after flashing.
   - **Files:**
     - Copy of the entire overlay `board/mscc/common/rootfs_overlay` to the output directory.
     - `etc/dropbear/dropbear.conf`: Dropbear configuration for development (root login allowed).

6. **Update kernel driver file**
   - **Goal:** Ensure the latest version of the LAN865x driver is always used in the kernel build to avoid issues from outdated drivers.
   - **File:**
     - `lan865x.c`: Current driver source in the kernel build directory.

7. **Set up Ethernet interfaces in the overlay**
   - **Goal:** Preconfigure eth0, eth1, and eth2 with static IP addresses so they are available and testable immediately after boot.
   - **File:**
     - `etc/network/interfaces`: Contains static configuration for eth0, eth1, eth2.

8. **Create init script for lan865x module autoload**
   - **Goal:** Ensure the lan865x kernel module is loaded automatically at boot, even with BusyBox init.
   - **File:**
     - `etc/init.d/S09lan865xmodprobe`: Shell script to load/unload the module at boot.

9. **Create load script for the target**
   - **Goal:** Provide a simple way to manually unload and reload the kernel module on the target (for debugging or updates).
   - **File:**
     - `root/load_lan865x.sh`: Shell script to unload and reload the module.

10. **Set up kernel module autoload (overlay)**
    - **Goal:** The lan865x module is loaded automatically at boot without manual intervention.
    - **File:**
      - `etc/modules-load.d/lan865x.conf`: Contains only the entry `lan865x`.

11. **Run build**
    - **Goal:** Rebuild the kernel and root filesystem with all changes so everything is included in the final image.
    - **Files:** All build and image files are regenerated.

12. **Post-build checks**
    - **Goal:** Ensure all key components (DTB, overlay, autoload, SSH) are correctly integrated and the system works as expected.
    - **Files:** No new files, but checks for generated DTB, overlay, and autoload files.

13. **Documentation**
    - **Goal:** Ensure traceability of all changes and copy operations for later analysis or audits.
    - **File:**
      - `CHANGES_DOCUMENTATION.md`: Logs all changes, timestamps, source and destination paths.

14. **Copy kernel module**
    - **Goal:** The built kernel module is copied to a fixed location outside the build system for quick access and reuse (e.g., testing, deployment).
    - **File:**
      - `/mnt/c/Users/M91221/work/lan9662/lan865x.ko`: Copy of the built kernel module.

15. **Copy brsdk_standalone_arm.ext4.gz image**
    - **Goal:** The built root filesystem image is copied to a fixed location for deployment or further processing.
    - **File:**
      - `/mnt/c/Users/M91221/work/lan9662/brsdk_standalone_arm.ext4.gz`: Copy of the built image.

---

**Last update:** 2026-01-28
