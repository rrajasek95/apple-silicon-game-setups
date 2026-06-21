# Skyrim Anniversary Edition on macOS (Apple Silicon)

```yaml
game: The Elder Scrolls V - Skyrim Anniversary Edition
store: GOG (offline installer)
game_version: 1.6.1179 (build 0.1.3905696 / 70738)
os: macOS 26
arch: Apple Silicon (tested M5 Pro, x86_64 game under Rosetta 2)
status: fully playable
difficulty: hard
stack: [Wine 11.10 staging, DXVK 2.3.1 (patched), MoltenVK 1.4.1, native Media Foundation, native XAudio2 2.7]
blockers_solved:
  - Wine 7.x (Whisky/GPTK) crashes in Skyrim's engine init — needs Wine 11
  - Upstream DXVK refuses to run on MoltenVK (force-requires Metal-unsupported Vulkan features)
  - Crash at main menu — xWMA audio needs Media Foundation + a real WMA codec
  - Crash on New Game — long GOG install path overflows an asset-path buffer
  - Controller axes/buttons scrambled — SDL mapping must use Wine's GUID, not an MFi tool's
  - Dialogue volume collapses when turning from an NPC — FAudio reports stereo output as 5.1
last_verified: 2026-06-21
```

Runs GOG Skyrim AE with **no CrossOver** — upstream Wine + a custom-patched DXVK + native Media
Foundation + native XAudio2/X3DAudio + a properly-mapped controller. Reaches gameplay, New Game works,
controller and spatial audio are correct.

## Canonical setup (verified known-good)

This is the exact combination verified working (see `last_verified` above). The versions were **not
chosen arbitrarily** — deviating from any line reintroduces the failure shown in the compatibility
matrix below. If you change nothing else, use exactly these:

| Layer | Use exactly | Source |
|---|---|---|
| Engine | Wine **Staging 11.10** (x86_64 / Rosetta 2) | [Gcenx `macOS_Wine_builds`](https://github.com/Gcenx/macOS_Wine_builds) |
| D3D11→Vulkan | **DXVK 2.3.1** + feature-relax patch | [`files/dxvk-2.3.1-moltenvk-feature-relax.patch`](files/dxvk-2.3.1-moltenvk-feature-relax.patch) |
| Vulkan→Metal | **MoltenVK 1.4.1** | swapped into the Wine app |
| Music / xWMA | native **Media Foundation** + `wmadmod.dll` | Windows install / Win7 SP1 KB976932 |
| SFX / 3D audio | native **XAudio2 2.7** + **X3DAudio1_7** | DirectX **June 2010** redist |
| Install path | short — game launched as `C:\Skyrim\SkyrimSE.exe` | symlink, step 6 |
| Input | controller via Wine SDL backend, mapping keyed to **Wine's** GUID | [`files/skyrim-gamepad-mapping.txt`](files/skyrim-gamepad-mapping.txt) |

## Compatibility matrix

Everything tried per layer and the outcome — so you know not just what to use but *what each choice
avoids*. **✅** canonical (use this) · **⚠️** works with a caveat · **❌** broken · **❓** untested.

| Layer | Option | | Why |
|---|---|:--:|---|
| **Wine** | 7.7 — Whisky / Apple GPTK / CrossOver-22 | ❌ | engine-init crash (`SkyrimSE.exe+0xE4B479`) before the menu |
| | 8.x – 10.x | ❓ | not tested — Gcenx ships only 11.x for macOS (an intermediate version *might* also work) |
| | **Staging 11.10 (Gcenx)** | ✅ | engine init works |
| **D3D11→Vulkan** | upstream DXVK 2.x | ❌ | won't enumerate MoltenVK (force-requires `geometryShader`, `nullDescriptor`, `transformFeedback`, …) → feature level 0 |
| | dxvk-macOS fork 1.10.3 | ❌ | has the relaxations but too old to run Skyrim AE |
| | Apple **D3DMetal** (GPTK) | ❌ | ABI-welded to Wine 7.7; can't graft onto Wine 11 |
| | **DXVK 2.3.1 + feature-relax patch** | ✅ | reaches `FEATURE_LEVEL_11_0` on MoltenVK |
| **Vulkan→Metal** | **MoltenVK 1.4.1** | ✅ | |
| **Music / xWMA** | Wine GStreamer (builtin) | ❌ | no WMA decoder → `CoCreateInstance` fails → crash in `mfplat.dll` at main menu |
| | **native MF stack + `wmadmod.dll`** | ✅ | |
| **SFX / 3D audio** | Wine **FAudio** (builtin xaudio2) | ⚠️ | plays, but `GetDeviceDetails` reports stereo output as 5.1 → dialogue collapses as you turn from NPCs |
| | native X3DAudio1_7 only (keep FAudio xaudio2) | ❌ | not enough — XAudio2 still builds the 5.1 mastering voice |
| | **native XAudio2 2.7 + X3DAudio1_7** | ✅ | stereo mastering voice; X3DAudio pans correctly within it |
| **Install path** | long (`C:\GOG Games\Skyrim Anniversary Edition\…`) | ❌ | the absolute asset path exceeds Skyrim's 116-byte buffer → New Game crash (`strcat_s`, `0xC0000417`) |
| | **short (`C:\Skyrim`, via symlink)** | ✅ | the absolute path now fits the buffer |
| **Input** | trackpad / mouse | ⚠️ | Wine's Mac driver has no raw-input mouse capture; camera is jittery even with acceleration off |
| | controller, mapping from an MFi-based tool | ❌ | the tool's GUID/layout (Apple vendor `05ac…`) never matches Wine's raw-HID GUID → scrambled |
| | **controller, mapping keyed to Wine's SDL GUID** | ✅ | correct XInput mapping |

**Why these:** Wine 11 (not 7.x) clears the engine-init crash; Metal lacks Vulkan features upstream DXVK
force-requires, so DXVK is patched; Skyrim's music is xWMA which Wine's GStreamer can't decode, so MF is
made native; Wine's FAudio misreports the device as 5.1, so XAudio2/X3DAudio are made native.

## Prerequisites
- The **GOG offline installer** for Skyrim AE (base game + Anniversary upgrade), installed under Wine.
- Homebrew (x86_64, `/usr/local`) with `mingw-w64`, `meson`, `ninja`, `glslang` (to build DXVK), and
  `cabextract` (to unpack the DirectX redist).
- A controller is strongly recommended (see step 8 — Wine's Mac driver can't do smooth raw-mouse capture).

> Conventions: `$HOME` = your home dir. `<GOG install dir>` = wherever the GOG installer put the game.
> `$PFX` = the Wine prefix, `$HOME/wine11-skyrim` below.

## Steps

### 1. Wine 11.10
Download **Wine Staging 11.10** from [Gcenx](https://github.com/Gcenx/macOS_Wine_builds) and place it at
`$HOME/wine-staging-11.10/Wine Staging.app`. Binary: `…/Contents/Resources/wine/bin/wine`.
*Why:* Wine 7.x (what Whisky and Apple's GPTK ship) crashes in Skyrim's engine init
(`SkyrimSE.exe+0xE4B479`, a refcounted-object destructor). Wine 11 fixed it.

### 2. MoltenVK 1.4.1
Replace `…/Wine Staging.app/Contents/Resources/wine/lib/libMoltenVK.dylib` with **1.4.1**.

### 3. Build the patched DXVK (2.3.1)
Apply [`files/dxvk-2.3.1-moltenvk-feature-relax.patch`](files/dxvk-2.3.1-moltenvk-feature-relax.patch)
to a DXVK 2.3.1 checkout, then cross-compile with mingw:
```bash
export PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin
cd dxvk && git apply dxvk-2.3.1-moltenvk-feature-relax.patch
meson setup --cross-file build-win64.txt --buildtype release build.w64
meson configure build.w64 -Denable_d3d9=false   # mingw d3d9.h clash
ninja -C build.w64
```
*Why:* upstream DXVK force-requires Vulkan features Metal lacks (`nullDescriptor`,
`robustBufferAccess2`, `geometryShader`, `transformFeedback`, `shaderCullDistance`) and bails with
feature-level 0. The patch makes them conditional so DXVK reaches `FEATURE_LEVEL_11_0` on MoltenVK.
Outputs: `build.w64/src/{d3d11/d3d11.dll, dxgi/dxgi.dll, d3d10/d3d10core.dll}`.

### 4. Create the prefix, install DXVK, set DLL overrides
```bash
export WROOT="$HOME/wine-staging-11.10/Wine Staging.app/Contents/Resources/wine"
export WINEPREFIX="$HOME/wine11-skyrim" DYLD_FALLBACK_LIBRARY_PATH="$WROOT/lib"
"$WROOT/bin/wine" wineboot --init
cp build.w64/src/d3d11/d3d11.dll      "$WINEPREFIX/drive_c/windows/system32/"
cp build.w64/src/dxgi/dxgi.dll        "$WINEPREFIX/drive_c/windows/system32/"
cp build.w64/src/d3d10/d3d10core.dll  "$WINEPREFIX/drive_c/windows/system32/"
```
Set these **native** in `HKCU\Software\Wine\DllOverrides`:
```
d3d11  dxgi  d3d10core
mfplat  mf  mferror  mfreadwrite  msmpeg2adec  msmpeg2vdec  sqmapi  wmadmod
xaudio2_7  x3daudio1_7
vcruntime140  vcruntime140_1  msvcp140  ucrtbase
```

### 5. Native Media Foundation + WMA codec (fixes main-menu crash)
Copy genuine Windows DLLs into `$PFX/drive_c/windows/system32/` (native, set above): the MF stack
(`mfplat, mf, mferror, mfreadwrite, msmpeg2adec, msmpeg2vdec`) plus **`wmadmod.dll`** (WMAudio Decoder
DMO, CLSID `{2eeb4adf-4578-4d10-bca7-bb955f56320a}`, from Win7 SP1 KB976932).
*Why:* Skyrim's menu/music is xWMA; Wine's GStreamer has no WMA decoder, so `CoCreateInstance` of the
decoder fails and the game crashes inside `mfplat.dll` at the main menu.

### 5b. Native XAudio2 2.7 + X3DAudio (fixes spatial/dialogue audio)
Extract the genuine Microsoft DLLs from the DirectX **June 2010** redist and override native:
```bash
cabextract -F '*Jun2010_XAudio_x64*'   directx_Jun2010_redist.exe   # -> XAudio2_7.dll
cabextract -F '*Feb2010_X3DAudio_x64*' directx_Jun2010_redist.exe   # -> X3DAudio1_7.dll
# copy both into $PFX/drive_c/windows/system32/ and override native (done in step 4 list)
```
*Why:* Wine's built-in FAudio answers XAudio2 2.7's `GetDeviceDetails` with **6 channels (5.1)** even on
stereo output, so Skyrim builds a 5.1 mastering voice and "behind you" voices collapse on the downmix —
dialogue drops sharply as you turn from an NPC. Genuine XAudio2 reports the real channel count (2), so
the mastering voice is stereo and X3DAudio pans correctly within it. (Native X3DAudio alone is *not*
enough — XAudio2 must be native too.)

### 6. Short install path (fixes New Game crash)
```bash
ln -sfn "<GOG install dir>" "$PFX/drive_c/Skyrim"   # launch the game as C:\Skyrim\SkyrimSE.exe
```
*Why:* Skyrim builds **absolute** asset paths into a fixed ~116-byte buffer. Under Wine's path
handling the long `C:\GOG Games\Skyrim Anniversary Edition\…` overflows it and New Game crashes
(`strcat_s`, `0xC0000417`). A short base path fits. Full forensics: [crash-forensics.md](crash-forensics.md).

### 7. Display config
In `$HOME/Documents/My Games/Skyrim Special Edition GOG/` (Wine maps Documents → Mac home):
- `SkyrimPrefs.ini` `[Display]`: `bFull Screen=1`, `iVSyncPresentInterval=0`
- `<game>/dxvk.conf`: `dxvk.maxFrameRate = 60` (Skyrim physics breaks above 60 fps) — see [files/dxvk.conf](files/dxvk.conf)

### 8. Controller (SDL backend + GUID-matched mapping)
Skyrim reads **XInput**. Route the pad through Wine's SDL backend and map it:
```bash
P="HKLM\\System\\CurrentControlSet\\Services\\winebus\\Parameters"
"$WROOT/bin/wine" reg add "$P" /v "Enable SDL"      /t REG_DWORD /d 1 /f
"$WROOT/bin/wine" reg add "$P" /v "Map Controllers" /t REG_DWORD /d 1 /f
```
The mapping **must use the GUID Wine's SDL assigns**, not a generic one. A mapping tool that reads the
pad via macOS's GameController framework produces an Apple-vendor GUID (`05ac…`) that never matches
Wine's raw-HID GUID. Find Wine's GUID by `dlopen`-ing the Wine-bundled `libSDL2-2.0.0.dylib` and calling
`SDL_JoystickGetDeviceGUIDString`, then take the matching layout from
[SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB) and swap in Wine's GUID.
Example for the 8BitDo Ultimate 2 Wireless is in
[files/skyrim-gamepad-mapping.txt](files/skyrim-gamepad-mapping.txt). The launcher feeds it via
`SDL_GAMECONTROLLERCONFIG`. Also set `[Controls] bGamepadEnable=1` in `Skyrim.INI`.

### 9. The launcher
Use [`files/play-skyrim.sh`](files/play-skyrim.sh) — it maintains the `C:\Skyrim` symlink, loads the
controller mapping, and launches the game from the short path.

## Key paths
- Launcher: [`files/play-skyrim.sh`](files/play-skyrim.sh)
- Wine: `$HOME/wine-staging-11.10/Wine Staging.app/Contents/Resources/wine/bin/wine`
- Prefix: `$HOME/wine11-skyrim` (game appears at `C:\Skyrim` via symlink)
- Config + saves: `$HOME/Documents/My Games/Skyrim Special Edition GOG/`

## Tuning / troubleshooting (symptom → root cause → fix)
- **Crash in engine init at launch** → Wine 7.x bug → use Wine 11 (step 1).
- **Crash at main menu** → no WMA decoder for xWMA music → native MF stack + `wmadmod.dll` (step 5).
- **Crash on New Game** → long install path overflows an asset buffer → launch from `C:\Skyrim` (step 6).
- **DXVK rejects the GPU / feature level 0** → Metal-unsupported Vulkan features → apply the DXVK patch (step 3).
- **Controller buttons/axes scrambled** → SDL mapping GUID ≠ Wine's GUID → re-key the mapping (step 8).
- **Dialogue volume collapses when turning from NPC** → FAudio reports stereo device as 5.1 → native XAudio2 2.7 (step 5b).
- **Low fps on first run** → DXVK compiling shaders → wait for `SkyrimSE.dxvk-cache` to fill.

## Known issues
- **Mild audio micro-stutter** on first entering a new area/effect: MoltenVK has no async pipeline
  compilation, so DXVK compiles each shader on first use — a brief frame stall that starves the 30 ms
  audio buffer. Self-resolving: each pipeline is cached to `SkyrimSE.dxvk-cache`, so a given shader
  stutters once then never again. Diminishes with playtime.
- **Trackpad/mouse camera is poor**: Wine's Mac driver doesn't implement raw-input mouse capture, and a
  trackpad has no relative-motion HID stream to forward. Use a controller (step 8) or a real mouse.

## Files
- `play-skyrim.sh` — the launcher (symlink + mapping + short-path run).
- `dxvk-2.3.1-moltenvk-feature-relax.patch` — the DXVK source patch (real diff).
- `dxvk.conf` — the 60 fps cap config.
- `skyrim-gamepad-mapping.txt` — example SDL mapping (8BitDo Ultimate 2), keyed to Wine's GUID.

## References

**Tooling**
- [Gcenx `macOS_Wine_builds`](https://github.com/Gcenx/macOS_Wine_builds) — the Wine 11.10 Staging build
- [DXVK](https://github.com/doitsujin/dxvk) — D3D11→Vulkan
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK) — Vulkan→Metal
- [SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB) — controller mapping layouts (source of the 8BitDo layout)
- [SDL2 Gamepad Tool](https://github.com/General-Arcade/sdl2-gamepad-tool) — generates SDL mapping strings

**Wine secure-CRT / path regression** (context for the New Game crash; the fix is the short path, not a Wine change)
- WineHQ forum: [*Debugging Assistance for Skyrim SE (wine 7.{7,8} → 7.6 Reversion)*, t=36530](https://forum.winehq.org/viewtopic.php?t=36530)
- Wine ANNOUNCE files documenting the secure-CRT string-function rework: [7.7](https://github.com/wine-mirror/wine/blob/wine-7.7/ANNOUNCE) · [7.12](https://github.com/wine-mirror/wine/blob/wine-7.12/ANNOUNCE) · [7.20](https://github.com/wine-mirror/wine/blob/wine-7.20/ANNOUNCE)
- [Wine `ucrtbase` API reference](https://source.winehq.org/WineAPI/ucrtbase.html)

**Microsoft redistributables** (you must obtain these yourself — they are *not* included in this repo)
- **DirectX End-User Runtimes (June 2010)** — source of genuine `xaudio2_7.dll` + `x3daudio1_7.dll` ([Microsoft Download Center, id=8109](https://www.microsoft.com/en-us/download/details.aspx?id=8109))
- **Windows 7 SP1 / KB976932** — source of `wmadmod.dll` (WMAudio Decoder DMO)

**Corroborating community guides**
- STEP: [*Linux WINE-ge GoG (non-Steam) Skyrim AE setup*](https://stepmodifications.org/forum/topic/20131-linux-wine-ge-gog-non-steam-focused-system-setup-guide/) — confirms the same GOG AE build runs on the Proton/wine-ge (CrossOver) lineage
- r/linux_gaming: [*Wine / Proton — Raw Mouse Input*](https://www.reddit.com/r/linux_gaming/comments/9l4iyd/wine_proton_raw_mouse_input/) — Wine forwards the desktop pointer, not true raw input
- r/skyrim: [*Guide: SSE on Linux with Wine*](https://www.reddit.com/r/skyrim/comments/8l9bez/guide_sse_on_linux_with_wine/)
