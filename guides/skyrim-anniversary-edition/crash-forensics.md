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
Starting a New Game, **Wine's `ucrtbase!strcat_s` raises `STATUS_INVALID_CRUNTIME_PARAMETER` (0xC0000417)** because Skyrim builds an **absolute** asset path into a fixed **116-byte** buffer, and under Wine that path includes the full install prefix — the long `C:\GOG Games\Skyrim Anniversary Edition\…` pushes the string past 116 bytes, so `strcat_s` (correctly) aborts. `strcat_s` is the messenger; the buffer is just too small for the long path. **Shortening the install path is the fix** — see the RESOLVED note above. The analysis below is the evidence trail.

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

## Conclusion / root cause
`strcat_s` is behaving **correctly** — the dest buffer (`destSize=116`) genuinely has no NUL in its
first 116 bytes because the string being assembled is **longer than 116 chars**: it's the *absolute*
asset path `C:\GOG Games\Skyrim Anniversary Edition\Data\…\Blacksmith…behavior.hkt`. The long GOG
install folder name is what pushes it over the limit.

Two facts combine:
1. **Skyrim uses a fixed ~116-byte buffer** for this asset path (an engine limitation, present on
   Windows too — but Windows feeds it a shorter/relative form).
2. **Under Wine's 7.7+ path handling, Skyrim receives the full absolute path** (with the install
   prefix) for this lookup, where on Windows it gets a shorter one.

So the practical, verified fix is to **make the install prefix short** — symlink the game to
`C:\Skyrim` and launch from there. The absolute path then fits in 116 bytes and `strcat_s` succeeds.
No Wine rebuild, native UCRT, or codepage change is needed (all were tried; only the short path
fixed it).

## Why Wine-specific (context, not required for the fix)
The same symptom class is documented as a Wine 7.6→7.7 regression ([WineHQ forum t=36530](https://forum.winehq.org/viewtopic.php?t=36530),
"Skyrim SE 7.{7,8} → 7.6 Reversion"); the secure-CRT string functions were reworked across
[7.7](https://github.com/wine-mirror/wine/blob/wine-7.7/ANNOUNCE)→[7.12](https://github.com/wine-mirror/wine/blob/wine-7.12/ANNOUNCE)→[7.20](https://github.com/wine-mirror/wine/blob/wine-7.20/ANNOUNCE). We
initially pursued a Wine-bug bisect down this path — but it proved unnecessary: the buffer-size
interaction with the install-path length is the real lever, and the short-path workaround is simpler
and version-independent. (Codepage experiments — `ACP=1252`, `LC_ALL=C` — were ruled out along the way.)

## Reproduction
Vanilla GOG Skyrim AE, New Game, Wine ≥ 7.7, with a long install path. Fixes with a short install path.
