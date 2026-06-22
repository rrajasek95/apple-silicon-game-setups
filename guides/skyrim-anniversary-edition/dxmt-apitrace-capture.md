# Capturing a DXMT D3D11 apitrace (Skyrim AE engine-init crash)

The DXMT maintainers diagnose with **apitrace**. A trace is the ideal report: it's the app's raw
D3D11/DXGI call stream, **replayable on their own DXMT** with no interpretation in the loop, and it
reproduces the bug without needing my whole build. This is the recipe I used; the resulting trace is
the thing to hand them.

**What you get:** a ~170 MB `.trace` that drives Skyrim AE to its engine-init crash
(`__cxa_pure_virtual`) under DXMT. The crash is early, so the trace stays small (≈4 GB/min otherwise —
keep time-to-event short).

## Prerequisites
- A working DXMT + Skyrim AE setup (this guide's CrossOver-26 / DXMT stack).
- **apitrace 13.0 win64** — `apitrace-13.0-win64.7z` from
  <https://github.com/apitrace/apitrace/releases/tag/13.0>. The wrappers are in
  `apitrace-13.0-win64/lib/wrappers/`: `d3d11.dll`, `dxgi.dll`, `dxgitrace.dll`.

## Steps
1. **Capture against a clean (crashing) DXMT** — install the stock DXMT builtin (no patches) so the
   trace ends at the real crash.
2. **Give apitrace a forwarding target.** apitrace forwards by loading the *real* `d3d11.dll`/`dxgi.dll`
   **as files**, so they must exist as **native files in the prefix's `system32`** — DXMT-as-builtin
   alone is not a file apitrace can open. (CrossOver hides this because its DXMT install differs; on a
   hand-rolled stack you must copy DXMT's `d3d11.dll` + `dxgi.dll` into `system32`.) Symptom if missing:
   `error: unavailable function CreateDXGIFactory` and a 0-byte trace.
   ```sh
   cp <dxmt>/x86_64-windows/d3d11.dll  $WINEPREFIX/drive_c/windows/system32/
   cp <dxmt>/x86_64-windows/dxgi.dll   $WINEPREFIX/drive_c/windows/system32/
   ```
3. **Overlay apitrace next to the game exe** (loaded first via the exe-directory search order):
   ```sh
   cp apitrace-13.0-win64/lib/wrappers/{d3d11.dll,dxgi.dll,dxgitrace.dll} "$WINEPREFIX/drive_c/Skyrim/"
   ```
4. **Launch with the override** so the game loads apitrace (native), which forwards to DXMT:
   ```sh
   WINEDLLOVERRIDES="d3d11,dxgi=n,b" wine ./SkyrimSE.exe
   ```
   (`winemetal`/`d3d10core` stay builtin — do not add them to the override.)
5. **Reproduce the event** — here, just launch; the crash hits during engine init (~15 s). apitrace
   logs `apitrace: tracing to C:\users\crossover\Desktop\SkyrimSE.trace` then
   `caught exception 0xc000001d` when DXMT traps.
6. **Collect the trace** at `$WINEPREFIX/drive_c/users/crossover/Desktop/SkyrimSE.trace`.
7. **Clean up:** remove the three apitrace DLLs from the game dir afterward.

## Verifying / replaying
Dump it with the same apitrace build (runs fine under Wine):
```sh
wine apitrace.exe dump --calls=0-18 "C:\users\crossover\Desktop\SkyrimSE.trace"
```
The head shows the real API stream (`CreateDXGIFactory`, `EnumAdapters`, `GetDisplayModeList`, …). The
maintainers can `apitrace replay` it on their DXMT to hit the same crash, or dump the tail to see the
final `Release` that lands on the freed resource (see
[`dxmt-skyrim-findings.md`](dxmt-skyrim-findings.md) §2 for the refcount analysis — but the trace is the
artifact to lead with; the analysis is supporting context, not a proposed fix).

**Captured artifact:** `skyrim-dxmt080-enginecrash.trace` (~170 MB; not committed — too large for git;
share via a file host). DXMT traced: **0.80 release** (verified to reproduce identically to the dev
commit `v0.80-27-g0606575`, so the crash is not a dev-build artifact).

> **Install note (this is the guide's non-builtin mode).** DXMT's `d3d11`/`dxgi`/`d3d10core` live as
> native files in `system32` (with `winemetal` builtin, override `WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b"`)
> — DXMT's own [non-builtin install](dxmt/03-install-dxmt.md), not a tracing deviation. The guide's
> builtin (`lib/wine`-only) mode needs a `d3d11` builtin/fakedll, which a Wine built `--without-vulkan`
> (no wined3d) doesn't have — there `lib/wine`-only aborts with `c0000135` (`d3d11.dll` not found).
