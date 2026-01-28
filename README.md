# Benötigte Quelldateien und ihre Bedeutung

Das Patch-Skript setzt voraus, dass folgende Dateien und Verzeichnisse im Projekt vorhanden sind:

- **lan966x-pcb8291.dts**: Device Tree Source für das Zielboard. Enthält die Hardware-Beschreibung, insbesondere die Definition des LAN865x-Knotens für die SPI-Anbindung.
- **lan865x.c**: Quellcode des LAN865x-Treibers. Wird in den Kernel-Build übernommen und als Modul gebaut.
- **linux.config**: Kernel-Konfigurationsdatei. Legt fest, welche Kernel-Optionen und Treiber beim Build aktiviert werden.
- **buildroot.config**: Buildroot-Konfigurationsdatei. Bestimmt, welche Pakete und Einstellungen für das Root-Filesystem und die Toolchain verwendet werden.
- **board/mscc/common/rootfs_overlay/**: Overlay-Verzeichnis mit Zusatzdateien für das Root-Filesystem (z.B. Netzwerkkonfiguration, SSH, Init-Skripte). Alle Inhalte werden ins Ziel-Rootfs kopiert.
- **output/<build_config>/build/linux-custom/arch/arm/boot/dts/microchip/**: Zielverzeichnis für Device Tree-Dateien im Kernel-Build.
- **output/<build_config>/build/**: Buildverzeichnis für alle Kernel- und Paketquellen.
- **output/<build_config>/build/linux-custom/**: Kernel-Buildverzeichnis mit allen Kernelquellen und -artefakten.
- **output/<build_config>/images/**: Verzeichnis für die erzeugten Images (Kernel, Rootfs, DTB, etc.).

Diese Dateien und Verzeichnisse sind für einen erfolgreichen Ablauf des Patch-Skripts zwingend erforderlich. Fehlt eine davon, bricht das Skript mit einer Fehlermeldung ab.

# Netzwerk-Konfiguration (Overlay)

Das Patch-Skript erzeugt im Overlay die Datei `/etc/network/interfaces` mit folgender statischer Netzwerkkonfiguration:

- **eth0**
  - IP-Adresse: 169.254.45.100
  - Netzmaske: 255.255.0.0
- **eth1**
  - IP-Adresse: 192.168.0.5
  - Netzmaske: 255.255.255.0
- **eth2**
  - IP-Adresse: 169.254.45.150
  - Netzmaske: 255.255.0.0

Diese Einstellungen sorgen dafür, dass alle drei Interfaces nach dem Booten sofort mit den jeweiligen Adressen verfügbar sind. Die Konfiguration ist in `/etc/network/interfaces` im Rootfs hinterlegt und wird beim Systemstart automatisch angewendet.

# Dokumentation: patch_bsp_lan8651.sh

Dieses Skript automatisiert die Vorbereitung und das Patchen einer Buildroot-Umgebung für die Entwicklung mit dem Microchip LAN8651 Modul auf einer LAN9662-Plattform. Es führt alle notwendigen Schritte aus, um Kernel, Device Tree, Overlays und Entwicklungs-Tools korrekt zu integrieren und zu konfigurieren.

## Übersicht der Schritte, Ziele und Dateiinhalte

1. **post-build.sh erzeugen**
   - **Ziel:** Nach dem Build automatisch SSH-Zugang für das Zielsystem einrichten, damit Entwickler sich direkt als root anmelden können. Das Skript setzt das Root-Passwort und aktiviert Dropbear-SSH.
   - **Datei-Inhalt:** Bash-Skript, das das Root-Passwort in /etc/shadow auf "microchip" setzt, Dropbear aktiviert und die Rechte für /etc/dropbear und /etc/shadow korrekt setzt.

2. **Eigene Konfigurationsdateien kopieren**
   - **Ziel:** Sicherstellen, dass die gewünschten Kernel- und Buildroot-Konfigurationen verwendet werden, um eine reproduzierbare und angepasste Buildumgebung zu gewährleisten.
   - **Dateien:**
     - `linux.config`: Enthält alle Kernel-Konfigurationsoptionen.
     - `buildroot.config`: Enthält alle Buildroot-Konfigurationsoptionen.

3. **Verzeichnis- und Dateiprüfungen**
   - **Ziel:** Vor dem Start des eigentlichen Patch- und Build-Prozesses prüfen, ob alle benötigten Dateien und Verzeichnisse vorhanden sind, um Fehler frühzeitig zu erkennen und den Build nicht ins Leere laufen zu lassen.
   - **Dateien:** Keine neuen Dateien, nur Prüfung.

4. **Device Tree kopieren und alte DTBs entfernen**
   - **Ziel:** Die aktuelle, angepasste Device Tree Source ins Buildsystem übernehmen und alte, möglicherweise fehlerhafte DTBs entfernen, damit nur die gewünschte Hardwarebeschreibung verwendet wird.
   - **Dateien:**
     - `lan966x-pcb8291.dts`: Device Tree Source mit allen Hardware-Definitionen.
     - Entfernte Dateien: alte .dtb-Dateien im Build- und Images-Verzeichnis.

5. **Overlay kopieren und konfigurieren**
   - **Ziel:** Entwicklungs-spezifische Anpassungen (z.B. SSH, Netzwerkkonfiguration) ins Root-Filesystem einbringen, damit das Zielsystem nach dem Flashen sofort einsatzbereit ist.
   - **Dateien:**
     - Kopie des gesamten Overlays `board/mscc/common/rootfs_overlay` ins Output-Verzeichnis.
     - `etc/dropbear/dropbear.conf`: Dropbear-Konfiguration für Entwicklung (Root-Login erlaubt).

6. **Kernel-Treiberdatei aktualisieren**
   - **Ziel:** Sicherstellen, dass immer die aktuelle Version des LAN865x-Treibers im Kernel-Build verwendet wird, um Fehler durch veraltete Treiber zu vermeiden.
   - **Datei:**
     - `lan865x.c`: Aktueller Treiberquelltext im Kernel-Build-Verzeichnis.

7. **Ethernet-Schnittstellen im Overlay einrichten**
   - **Ziel:** Die Netzwerkschnittstellen eth0, eth1 und eth2 mit festen IP-Adressen vorkonfigurieren, damit sie nach dem Booten sofort verfügbar sind und getestet werden können.
   - **Datei:**
     - `etc/network/interfaces`: Enthält statische Konfigurationen für eth0, eth1, eth2.

8. **Init-Skript für lan865x-Modul-Autoload erzeugen**
   - **Ziel:** Automatisches Laden des lan865x-Kernelmoduls beim Systemstart sicherstellen, auch wenn BusyBox-Init verwendet wird.
   - **Datei:**
     - `etc/init.d/S09lan865xmodprobe`: Shell-Skript, das das Modul beim Booten lädt oder entlädt.

9. **Ladeskript für das Target erzeugen**
   - **Ziel:** Einfache Möglichkeit bieten, das Kernelmodul auf dem Zielsystem manuell zu entladen und neu zu laden, z.B. für Debugging oder Updates.
   - **Datei:**
     - `root/load_lan865x.sh`: Shell-Skript, das das Modul entlädt und neu lädt.

10. **Kernelmodul-Autoload (Overlay) einrichten**
    - **Ziel:** Das lan865x-Modul wird beim Systemstart automatisch geladen, ohne dass ein manuelles Eingreifen nötig ist.
    - **Datei:**
      - `etc/modules-load.d/lan865x.conf`: Enthält nur den Eintrag `lan865x`.

11. **Build ausführen**
    - **Ziel:** Den Kernel und das Root-Filesystem mit allen Änderungen neu bauen, damit alle Anpassungen im finalen Image enthalten sind.
    - **Dateien:** Alle Build- und Image-Dateien werden neu erzeugt.

12. **Prüfungen nach dem Build**
    - **Ziel:** Sicherstellen, dass alle wichtigen Komponenten (DTB, Overlay, Autoload, SSH) korrekt integriert wurden und das System wie erwartet funktioniert.
    - **Dateien:** Keine neuen Dateien, aber Prüfung der erzeugten DTB, Overlay- und Autoload-Dateien.

13. **Dokumentation**
    - **Ziel:** Nachvollziehbarkeit aller Änderungen und Kopiervorgänge für spätere Analysen oder Audits gewährleisten.
    - **Datei:**
      - `CHANGES_DOCUMENTATION.md`: Protokolliert alle durchgeführten Änderungen, Zeitstempel, Quell- und Zielpfade.

14. **Kopieren des Kernelmoduls**
    - **Ziel:** Das gebaute Kernelmodul wird für den schnellen Zugriff und die Weiterverwendung (z.B. Test, Deployment) an einen festen Ort außerhalb des Buildsystems kopiert.
    - **Datei:**
      - `/mnt/c/Users/M91221/work/lan9662/lan865x.ko`: Kopie des gebauten Kernelmoduls.

---

**Letzte Änderung:** 2026-01-28
