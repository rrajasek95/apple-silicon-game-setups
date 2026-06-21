# DXMT v2 — investigation & the exact blocker (open)

Status: **spike, blocked at the final step.** This documents an attempt to replace the graphics stack
(patched DXVK + MoltenVK, two hops: D3D11→Vulkan→Metal) with **[DXMT](https://github.com/3Shain/dxmt)**
— a one-hop **D3D11→Metal** translator — on the *free* Gcenx-lineage Wine, with no CrossOver.

**Outcome:** DXMT loads and **creates a Direct3D 11 device at `FEATURE_LEVEL_11_0`** on a self-built,
patched Wine — proving the approach is viable. It then fails at one specific call (creating the Metal
view) due to a Wine-internal symbol-visibility difference between upstream Wine and CrossOver. That last
hurdle is **not yet solved.** The working guide ([README](README.md)) still uses DXVK + MoltenVK.

## Why DXMT
- One translation hop instead of two; talks to Metal natively → no MoltenVK, and **no DXVK feature patch**
  (DXMT doesn't hit MoltenVK's missing-Vulkan-features problem at all).
- Actively developed (v0.80, Apr 2026), shipped as an option in CrossOver 25/26. Skyrim is pure D3D11 —
  squarely in scope.

## The catch DXMT documents
DXMT's `winemetal.so` resolves Wine's Metal-view functions from `winemac.drv` — functions that exist in
Wine but are compiled **hidden** (`-fvisibility=hidden`). DXMT is built against **CrossOver Wine 24+**
(or a self-built Wine ≥8 with those symbols exposed). So the prerequisite is a Wine that exports them.

## What was built (reproducible, and it works to device creation)
1. **Built Wine 11.10 from source** with a patch exposing the `winemac.drv` Metal symbols
   ([`files/wine-11.10-dxmt-winemac-export.patch`](files/wine-11.10-dxmt-winemac-export.patch)):
   - `visibility("default")` on the 8 functions DXMT needs (`macdrv_create_metal_device`,
     `macdrv_view_create_metal_view`, `macdrv_view_get_metal_layer`, `get_win_data`, …).
   - a CrossOver-compatible global **`macdrv_functions`** struct (DXMT's preferred resolution target).
   - **Build note:** the host compiler defaults to **arm64**, but DXMT v0.80 ships an **x86_64**
     `winemetal.so` (the traditional x86_64-under-Rosetta layout). You must build **x86_64** Wine
     (`arch -x86_64 ./configure … --enable-archs=x86_64`, `--without-freetype` etc. are fine if you
     only need `winemac.so` to graft). An arm64 Wine will not host DXMT's x86_64 components.
2. **Grafted** the patched x86_64 `winemac.so` into a copy of the Gcenx Wine 11.10 (the rest of Wine
   stays Gcenx's, so it's known-good for Skyrim's engine).
3. **Installed DXMT v0.80** (`dxmt-*-builtin.tar.gz`): `winemetal.so` → `lib/wine/x86_64-unix/`;
   `d3d11.dll`, `dxgi.dll`, `d3d10core.dll`, `winemetal.dll` → both `lib/wine/x86_64-windows/` and the
   prefix `system32`. Set those four DLL overrides to **`builtin`** (critical — `winemetal` only loads
   its unixlib when loaded as builtin; `native` fails with err 126).
4. Reused everything graphics-independent from the main guide (short path, native MF/XAudio2 audio).

**Result:** DXMT's `SkyrimSE_d3d11.log` reports:
```
info:  Maximum supported feature level: D3D_FEATURE_LEVEL_11_1
info:  Using feature level D3D_FEATURE_LEVEL_11_0
err:   Failed to create metal view, it seems like your Wine has no exported symbols needed by DXMT.
```

## The blocker (precisely characterized)
DXMT resolves the Metal-view API via **`dlsym(RTLD_DEFAULT, "macdrv_functions")`** (then a fallback to
individual `dlsym`s) from inside `winemetal.so`. On this Wine that returns **NULL**, even though the
symbols are correctly exported by the grafted `winemac.so` and the module is loaded.

Evidence gathered (symptom → cause → ruled-out):
- The symbols **are** exported (`nm -gU winemac.so` shows all 8 + `macdrv_functions`).
- `winemac.so` **is** loaded, and from **its own** context the symbol resolves — an instrumented
  constructor in `winemac.so` saw `dlsym(RTLD_DEFAULT,"macdrv_functions") != NULL` (`before=1`).
- From **`winemetal.so`** (a *separate* unixlib), the same `dlsym` returns NULL.
- **Ruled out — `RTLD_GLOBAL`/scope:** a standalone macOS test proved a `dlopen`'d library's symbols are
  visible to `dlsym(RTLD_DEFAULT)` from a *separate* image **without** `RTLD_GLOBAL`. Wine `dlopen`s its
  unixlibs `RTLD_NOW`, which the test shows is sufficient — so the dlopen flags are not the cause.
- **Ruled out — missing struct:** adding the CrossOver-style `macdrv_functions` struct didn't change it.
- **Ruled out — self-promotion:** a `dlopen(self, RTLD_GLOBAL|RTLD_NOLOAD)` constructor doesn't help —
  macOS `RTLD_NOLOAD` does not promote an already-loaded image's scope.

**Conclusion:** under upstream Wine-WoW64, DXMT's `winemetal.so` and Wine's `winemac.so` end up in
**separate symbol-resolution contexts**, so cross-module `dlsym(RTLD_DEFAULT)` fails. CrossOver's Wine
keeps them mutually visible (which is why DXMT works there). The difference is in *how CrossOver loads
unixlibs*, not in a flag or a missing symbol — so it can't be fixed from `winemac.drv` alone.

## Where it could go from here
- **Most realistic:** build/obtain a **FOSS CrossOver-sources Wine 24+** (DXMT's reference target) and
  drop DXMT in — skip the upstream-Wine fight entirely.
- **Deep path:** reverse-engineer CrossOver's unixlib loading and replicate it in upstream Wine's
  `ntdll` unix loader (so unixlibs share a symbol context). Uncertain, and a full Wine rebuild.
- **Off the free track:** CrossOver 25/26 exposes DXMT as a one-click Graphics option.

## Files
- [`files/wine-11.10-dxmt-winemac-export.patch`](files/wine-11.10-dxmt-winemac-export.patch) — the
  `winemac.drv` symbol-exposure + `macdrv_functions` patch (correct and reusable; the remaining blocker
  is in Wine's loader, not this patch).
