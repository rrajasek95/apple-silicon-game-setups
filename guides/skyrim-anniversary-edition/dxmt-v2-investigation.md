# DXMT v2 — investigation: from "blocked" to a validated architecture (still one DXMT bug short)

Status: **the hard architectural problem is solved; the remaining blocker is a bug inside DXMT, not in
our stack.** This documents replacing the graphics stack (patched DXVK + MoltenVK, two hops:
D3D11→Vulkan→Metal) with **[DXMT](https://github.com/3Shain/dxmt)** — a one-hop **D3D11→Metal**
translator — on **free, from-source CrossOver Wine**, with no commercial CrossOver.

**Bottom line:**
- ✅ Built **CrossOver-26 Wine (Wine 11.0 base) from source** on macOS 26 / Apple Silicon.
- ✅ DXMT loads on it and drives **D3D11 device @ FL11_0 → Metal swapchain (a real `CAMetalLayer`
  window) → first pipeline (PSO) compilation.** The symbol-visibility wall that defeated every
  upstream-Wine attempt is **gone.**
- ❌ Skyrim then crashes with **"Pure virtual function called"** — DXMT returns an
  **incompletely-constructed D3D11 COM object** during engine init, and Skyrim's cleanup `Release()`s it.
  Present in **both DXMT v0.80 and the latest dev build (Jun 2026)**. This is a DXMT bug.

The shipping guide ([README](README.md)) still uses the rock-solid DXVK + MoltenVK path.

---

## Part 1 — Why the upstream-Wine approach was a dead end (solved by switching Wine)

DXMT's `winemetal.so` resolves Wine's Metal-view functions from `winemac.drv` via
`dlsym(RTLD_DEFAULT, "macdrv_functions")`. On a self-built **upstream** Wine 11.10 — even with the
symbols exported and a hand-written `macdrv_functions` struct — that `dlsym` returns **NULL** from
`winemetal.so`, although `winemac.so` exports it and resolves it from its *own* context.

Ruled out with evidence: the `dlopen` flags (CrossOver uses the **same** `RTLD_NOW` — confirmed by
diffing `dlopen_dll` in both sources), `RTLD_GLOBAL`/scope (a standalone macOS test showed cross-image
`dlsym` works without it), the missing struct, and self-promotion (`RTLD_NOLOAD` doesn't promote on
macOS). The difference is **diffuse**, woven through CrossOver's wider Wine fork — not a liftable
one-liner. So we stopped trying to patch upstream Wine and **built CrossOver's Wine instead.**

### Confirmed by reading CrossOver's source
CrossOver defines `macdrv_functions` in a proprietary **`dlls/winemac.drv/d3dmetal.c`** (the Wine-side
hooks D3DMetal uses — *not* D3DMetal itself), exported `DECLSPEC_EXPORT`, as a **24-field / 192-byte**
struct. DXMT reads the first 10 fields (`get_win_data`, `macdrv_create_metal_device`,
`macdrv_view_create_metal_view`, …). Crucially **`d3dmetal.c` includes only standard Wine headers** —
no Apple `D3DMetal.framework` dependency — so it builds in a plain Wine tree.

---

## Part 2 — Building CrossOver-26 Wine from source (reproducible)

Sources: `https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.0.0.tar.gz`
(Wine 11.0 base; the Wine tree is under `sources/wine/`, with `configure` already generated).

**Architecture decisions (and why):**
- **x86_64** under Rosetta — DXMT v0.80 ships only an x86_64 `winemetal.so`; SkyrimSE.exe is x86_64 PE.
- **WoW64 single-binary** (`--enable-archs=x86_64`).
- **Whole, consistent fork** — the symbol visibility is diffuse, so build all of CrossOver's Wine so it
  "just works" rather than grafting pieces.
- Deps from **x86_64 Homebrew** (`/usr/local`): freetype (the thing that blocked the upstream x86_64
  build is just-works here), bison, mingw-w64, SDL2. Skip Vulkan/MoltenVK (DXMT→Metal direct) and
  gstreamer (native Media Foundation).

```sh
# x86_64 Homebrew deps already present at /usr/local: freetype, bison, mingw-w64, sdl2
arch -x86_64 /bin/bash -c '
  export PATH=/usr/local/opt/bison/bin:/usr/local/bin:/usr/bin:/bin
  export PKG_CONFIG_PATH=/usr/local/opt/freetype/lib/pkgconfig:/usr/local/opt/sdl2-compat/lib/pkgconfig
  export CPPFLAGS=-I/usr/local/include LDFLAGS=-L/usr/local/lib
  mkdir build && cd build
  ../sources/wine/configure --enable-archs=x86_64 --disable-tests --without-gstreamer
  nice -n 5 make -j6     # ~11k files, x86_64 under Rosetta; -j6 keeps peak RAM ~18GB (48GB box)
'
```

**One source patch needed** (`win32u/vulkan.c`): CrossOver's `win32u/vulkan.c` references
`SONAME_LIBVULKAN` unconditionally, which `--without-vulkan` leaves undefined. Add a fallback so it
compiles (the path is never exercised by DXMT):
```c
#ifndef SONAME_LIBVULKAN
#define SONAME_LIBVULKAN "libvulkan.1.dylib"
#endif
```
Then `make install DESTDIR=~/cx-wine`. Result: `winemac.so` **exports `macdrv_functions`** (from
`d3dmetal.c`) — verify with `nm -gU .../x86_64-unix/winemac.so | grep macdrv_functions`.

**Install DXMT** into the CrossOver Wine (builtin layout): `winemetal.so` → `lib/wine/x86_64-unix/`;
`d3d11/dxgi/d3d10core/winemetal/nvapi64.dll` → `lib/wine/x86_64-windows/` (+ prefix `system32` as
locators), overrides = **`builtin`**. Runtime: put freetype on the dyld path
(`DYLD_FALLBACK_LIBRARY_PATH=/usr/local/opt/freetype/lib:/usr/local/lib:/usr/lib`) or Wine reports
"cannot find the FreeType font library." A prefix made by another Wine triggers one `wineboot --init`
on first run — let it finish, then relaunch.

---

## Part 3 — How far DXMT gets, and the exact failure (DXVK side-by-side)

Same Mac, same Skyrim AE, same prefix. DXVK is the known-good reference (reaches gameplay).

| Stage | DXVK (D3D11→Vulkan→Metal) | DXMT (D3D11→Metal) |
|---|---|---|
| D3D11 device @ `FL11_0` | ✅ | ✅ |
| Swapchain / `CAMetalLayer` | ✅ 3 images @ 1734×1080 | ✅ (black window appears) |
| 1st pipeline (PSO) compile | ✅ | ✅ `Compiled 1 PSO` |
| 2nd pipeline + continued engine init | ✅ compiles ≥2, **runs to menu** | ❌ **crash** |
| `Pure virtual function called` | 0 | 1 |

**The crash, precisely.** DXMT's own trace ends:
```
info:  Using feature level D3D_FEATURE_LEVEL_11_0
warn:  MakeWindowAssociation: Ignoring flags 3
trace: Start compiling 1 PSO
trace: Compiled 1 PSO
err:   Pure virtual function called
```
Backtrace at the abort (CrossOver Wine + DXMT):
```
=>0  d3d11 (+0x1e4fd)   ud2            ; preceded by `call _ZdlPvy` (operator delete) — object teardown
  1  skyrimse (+0xe4b47c)              ; call *0x10(%rax)  → COM vtable index 2 = Release()
  2..5 skyrimse (engine-init cleanup chain)
  6  kernel32 / 7 ntdll (thread start)
```
`skyrimse+0xe4b47c` is the **same engine-init cleanup function** (`+0xE4B479`) that the Wine-7.7 bug
also crashed in — Skyrim's error/teardown path. It `Release()`s a D3D11 object whose COM vtable slot 2
is still the **pure-virtual stub**: DXMT handed back a **half-constructed object** right after the first
pipeline. DXVK constructs that same object fully and continues. So *what's incomplete in DXMT* is a
**D3D11 object-lifecycle bug**, not anything in our Wine/MoltenVK/audio stack.

This reproduces on **both** DXMT v0.80 and the latest CI dev build (commit `06065754`, 2026-06-20,
which adds `IMTLSwapChainFactory` / `IDXGISurface` work — close to this area but not a fix). Skyrim is
not on DXMT's tested-games list, so this is likely first-discovery territory.

---

## Where it goes from here
- **Report upstream to DXMT** — this is their bug, with a concrete repro: device + swapchain + 1 PSO
  succeed, then a pure-virtual `Release` on a half-built D3D11 object during Skyrim AE engine init
  (backtrace above). The DXVK side-by-side pins the divergence to the object created right after the
  first pipeline.
- **Bank the architecture** — `~/cx-wine` is a working free CrossOver-26 Wine that hosts DXMT to an
  on-screen swapchain; when DXMT closes this gap it should "just work." Keep playing on DXVK meanwhile.
- **Off the free track:** commercial CrossOver 25/26 exposes DXMT as a one-click Graphics option.

## Files / artifacts
- [`files/wine-11.10-dxmt-winemac-export.patch`](files/wine-11.10-dxmt-winemac-export.patch) — the
  upstream-Wine symbol-exposure patch (historical; superseded by building CrossOver Wine, where
  `d3dmetal.c` already exports `macdrv_functions`).
- Local build tree `~/cx-wine-build` (CrossOver-26 source + `build/`), installed Wine `~/cx-wine`,
  test prefix `~/dxmt-skyrim-prefix`, latest DXMT dev build under `/tmp/dxmt-new`.
