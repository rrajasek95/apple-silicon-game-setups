# Skyrim AE "New Game" crash — Wine stack-trace audit

## ✅ RESOLVED (2026-06-21) — it was the install-path LENGTH
The crash is fixed **for free on Wine 11** by running the game from a **short install path**.
Root cause: Skyrim builds **absolute** asset paths (e.g. the Blacksmith Havok `.hkt`) into a fixed
~116-byte buffer. Under the Wine 7.7+ path-handling change, Skyrim gets the long *absolute* path
(`C:\GOG Games\Skyrim Anniversary Edition\Data\...`) where Windows used a shorter/relative one — and
the long GOG folder name overflowed the buffer, tripping `strcat_s`'s C11 bounds check → `0xC0000417`.
**Fix:** symlink the game to `C:\Skyrim` and launch from there (`~/play-skyrim.sh` does this). No
CrossOver, no Wine rebuild, no native UCRT needed. This matches the STEP Linux guide author, who also
shortened the install path to `C:\Skyrim`. The detailed analysis below is retained for the record.

---

## One-line summary
Starting a New Game, **Wine's builtin `ucrtbase!strcat_s` raises `STATUS_INVALID_CRUNTIME_PARAMETER` (0xC0000417)** because the destination buffer Skyrim passes is **not NUL-terminated within its declared size** — under Wine. Same call succeeds on Windows, so an **upstream Wine API** that fills/sizes this path buffer is the real culprit. `strcat_s` is just where it surfaces.

## Environment
- Wine: **wine-staging 11.10**, x86_64 (under Rosetta 2), prefix `~/wine11-skyrim`
- OS: macOS 26.5.1, Apple M5 Pro
- Game: GOG **Skyrim Anniversary Edition**, exe runtime **1.6.1179** (ImageBase 0x140000000)
- `ucrtbase.dll`: **Wine builtin** (native `vcruntime140`/`msvcp140` installed, but `ucrtbase` is Wine's)
- Renderer/audio (custom DXVK + native Media Foundation) are **not** involved — this is pure CRT/string.

## Exception
```
Unhandled exception: 0xc0000417 (STATUS_INVALID_CRUNTIME_PARAMETER) in 64-bit code (0x6fffffc24f93)
flags=1 (EXCEPTION_NONCONTINUABLE) -> unhandled -> process terminates (rc=23)
```
Raised by `RaiseException` (kernelbase) from `ucrtbase!strcat_s`. NOTE: terminates via the CRT fail-fast path, so Wine's AeDebug does NOT fire — must attach winedbg from start to capture.

## Backtrace (winedbg, attached)
```
=>0 kernelbase (+0x14f93)        RaiseException
  1 ucrtbase  (+0x653cb)         strcat_s (export +0x652e0) + 0xeb  -> the _invalid_parameter / ERANGE branch
  2 skyrimse  (+0xd11393)        <- direct caller of strcat_s
  3 skyrimse  (+0xd11bee)
  4 skyrimse  (+0xd0e5c4)
  5 skyrimse  (+0xd0e6b9)
  6 skyrimse  (+0x53f753)
  7 skyrimse  (+0xbacb5c)
  8 skyrimse  (+0xbaa457)
  9 skyrimse  (+0xbc6962)
 10 skyrimse  (+0xbcad20)
 11 skyrimse  (+0xbc36a3)
 12 skyrimse  (+0xbb23d6)
 13 skyrimse  (+0x54bc71)
 14 skyrimse  (+0x54ce1e)
 15 skyrimse  (+0x18f18c)
 16 skyrimse  (+0x18e068)
 17 skyrimse  (+0x18f7f3)
 18 skyrimse  (+0xcd287d)        thread proc
 19 kernel32  (+0x27759)         BaseThreadInitThunk
 20 ntdll     (+0x5767f)         RtlUserThreadStart
```
Crashing thread is a freshly-spawned worker (does `DLL_THREAD_ATTACH` for vcruntime140_1 / opengl32 / dxgi / d3d11 immediately before).

## Registers at fault (in strcat_s)
```
rbx=0x74 (116)  = likely destSize
rcx=rax=0x19377e260  = dest buffer (on the stack)
rdi=0x19377e640  = src
rsi=0x19377e3a0
```

## What strcat_s actually checks (Wine ucrtbase disasm @ 0x180065...)
```
strcat_s(dest,destSize,src):
  if !dest || !destSize -> invalid_parameter
  scan dest for a NUL within destSize bytes
  if none found in destSize bytes -> call _invalid_parameter; return ERANGE(0x22)   <-- WE HIT THIS
```
This is the standard C11 Annex-K behavior (real Windows ucrtbase does the same). So the dest buffer genuinely lacks a NUL in its first 116 bytes **under Wine**.

## The buffer content (decoded UTF-16 from the stack dump)
Path fragments on the stack around the dest buffer:
```
"\Blacksm"  …  "ing P"  …  "ct.hkt"
```
i.e. Skyrim is **building a Blacksmith/crafting Havok behavior asset path** (`...\Blacksmith...ing ...ct.hkt`) during new-game data/behavior loading. The crash is in **path-string construction**.

## Conclusion / where the real bug is
`strcat_s` is correct. The dest buffer is non-NUL-terminated because some **upstream Wine string/path API returned a different result than Windows** (longer string, missing terminator, or different length accounting), leaving the buffer un-terminated before `strcat_s` runs. Find that API.

## Regression window (already established)
- **Works: Wine 7.6.  Breaks: Wine 7.7+** — WineHQ forum t=36530 ("Skyrim SE 7.{7,8} -> 7.6 Reversion"). Same symptom class (cell/data load crash).
- Secure-CRT string fns reworked across 7.7 → 7.12 (moved to ntdll, unified) → 7.20 (strcat_s error-handling). **Still present in 11.10.**
- Only CRT line in the 7.7 ANNOUNCE: `msvcrt: Fix mbcs initialization for UTF-8 codepage` — but forcing ACP=1252 and `LC_ALL=C` did NOT fix it, so the regressing commit is likely elsewhere in the 7.6→7.7 range.

## Research leads for Wine Bugzilla / git bisect
1. Search Bugzilla: `Skyrim strcat_s`, `STATUS_INVALID_CRUNTIME_PARAMETER`, `invalid parameter` cell/load.
2. Bisect Wine 7.6→7.7; focus on commits touching: path normalization, `RtlDosPathNameToNtPathName`, `GetModuleFileName`, `ExpandEnvironmentStrings`, `GetFullPathName`, msvcrt string/`_mbs*`/`wcs*` length funcs, or the behavior/file loader path building.
3. Map the SkyrimSE.exe RVAs above to function names using the **Address Library for SKSE Plugins (1.6.1179)** + a crashlog decoder, to learn exactly which engine routine builds this path (frame 2 = `SkyrimSE.exe+0xd11393`).
4. Repro is reliable: vanilla GOG AE, New Game, Wine ≥7.7.
