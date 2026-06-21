#!/bin/bash
# Skyrim Anniversary Edition (GOG) launcher for macOS / Apple Silicon.
# Stack: Wine 11.10 staging + patched DXVK 2.3.1 + MoltenVK 1.4.1 + native MF/XAudio2.
# See the guide README for the full setup. Only the two paths below are machine-specific.

# ======== EDIT THESE TWO FOR YOUR MACHINE ========
# 1) The Gcenx "Wine Staging" app you downloaded (path to its bundled wine root):
WROOT="$HOME/wine-staging-11.10/Wine Staging.app/Contents/Resources/wine"
# 2) Where the GOG installer actually put Skyrim AE (the folder containing SkyrimSE.exe):
GOG_INSTALL_DIR="$HOME/Games/Skyrim Anniversary Edition"
# =================================================

# Wine prefix created in step 4 of the guide (holds drive_c, registry, DLL overrides):
export WINEPREFIX="$HOME/wine11-skyrim"
export DYLD_FALLBACK_LIBRARY_PATH="$WROOT/lib"
export WINEESYNC=1 WINEMSYNC=1 WINEDEBUG=-all
export DXVK_HUD=fps          # remove to hide the FPS counter

# Controller mapping (SDL_GameControllerDB layout keyed to WINE's SDL GUID — see step 8).
# Point this at your mapping file; comment out if you play with mouse/keyboard.
MAP_FILE="$HOME/skyrim-gamepad-mapping.txt"
[ -f "$MAP_FILE" ] && export SDL_GAMECONTROLLERCONFIG="$(grep -v '^[[:space:]]*#' "$MAP_FILE" | tr -d '\r')"

# CRITICAL: launch from a SHORT path. The long GOG install path overflows an asset-path buffer
# and crashes New Game (see crash-forensics.md). This symlink makes the game appear at C:\Skyrim.
if [ ! -e "$GOG_INSTALL_DIR/SkyrimSE.exe" ]; then
  echo "SkyrimSE.exe not found under GOG_INSTALL_DIR — edit that path at the top of this script." >&2
  exit 1
fi
ln -sfn "$GOG_INSTALL_DIR" "$WINEPREFIX/drive_c/Skyrim" 2>/dev/null

cd "$WINEPREFIX/drive_c/Skyrim" || exit 1
exec "$WROOT/bin/wine" ./SkyrimSE.exe
