#!/bin/bash
# Skyrim AE on macOS — Wine 11.10 + custom DXVK + native MF.  Runs from C:\Skyrim (short path; long
# GOG path overflows an asset buffer and crashes New Game). Controller via SDL backend + XInput map.
WROOT="$HOME/wine-staging-11.10/Wine Staging.app/Contents/Resources/wine"
export WINEPREFIX="$HOME/wine11-skyrim"
export DYLD_FALLBACK_LIBRARY_PATH="$WROOT/lib"
export WINEESYNC=1 WINEMSYNC=1 WINEDEBUG=-all
export DXVK_HUD=fps
# --- custom controller mapping from SDL2 Gamepad Tool (if present) ---
MAP_FILE="$HOME/skyrim-gamepad-mapping.txt"
if [ -f "$MAP_FILE" ]; then
  export SDL_GAMECONTROLLERCONFIG="$(grep -v '^[[:space:]]*#' "$MAP_FILE" | tr -d '\r' | paste -sd $'\n' -)"
fi
# keep the short-path symlink current
GAME="$HOME/Library/Containers/com.isaacmarovitz.Whisky/Bottles/F0472221-F0C7-4393-816C-E39A4D31B9AE/drive_c/GOG Games/Skyrim Anniversary Edition"
ln -sfn "$GAME" "$WINEPREFIX/drive_c/Skyrim" 2>/dev/null
cd "$WINEPREFIX/drive_c/Skyrim" || exit 1
exec "$WROOT/bin/wine" ./SkyrimSE.exe
