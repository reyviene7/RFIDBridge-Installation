============================================================
  WAREHOUSE FITNESS — RFID Bridge
  Version 1.0
============================================================

WHAT IS THIS?
─────────────
This program connects your USB RFID card reader to the
Warehouse Fitness management system. It runs silently in
the background and starts automatically when Windows boots.

REQUIREMENTS
────────────
  • Windows 10 or 11 (64-bit)
  • ESP32 plugged in via USB before (or after) boot
  • Internet connection for Supabase sync

INSTALLATION STEPS
──────────────────
1. Right-click "install.bat" → Run as Administrator
2. Enter your ESP32 COM port when prompted
   (Check Device Manager → Ports to find it, e.g. COM11)
3. Enter your Supabase URL and Key when prompted
4. Done! The bridge starts automatically.

AFTER INSTALL
─────────────
  Install location : C:\RFIDBridge\
  Config file      : C:\RFIDBridge\.env
  Log file         : C:\RFIDBridge\rfid_bridge.log
  Auto-start       : Yes — every boot (30 second delay)

CHANGING SETTINGS LATER
────────────────────────
Open C:\RFIDBridge\.env in Notepad and edit the values.
Then restart the rfid_bridge.exe or reboot.

COMMON COM PORTS
────────────────
To find which COM port the ESP32 uses:
  1. Open Device Manager (Win + X → Device Manager)
  2. Expand "Ports (COM & LPT)"
  3. Look for "Silicon Labs CP210x" or "CH340" — that's your ESP32

TROUBLESHOOTING
───────────────
  Problem: Lock not opening after RFID scan
  → Check rfid_bridge.log for errors
  → Make sure ESP32 is plugged in and COM port matches .env

  Problem: "ESP32 not found — retrying in 5s"
  → Plug in the ESP32; bridge will auto-connect

  Problem: Bridge not starting on boot
  → Open Task Scheduler → check "WarehouseFitness_RFIDBridge"
  → Or run C:\RFIDBridge\rfid_bridge.exe manually

UNINSTALL
─────────
Run C:\RFIDBridge\uninstall.bat as Administrator

SUPPORT
───────
Contact your system administrator for assistance.
============================================================
