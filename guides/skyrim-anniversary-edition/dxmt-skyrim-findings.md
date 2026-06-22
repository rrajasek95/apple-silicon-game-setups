# DXMT + Skyrim Anniversary Edition on Apple Silicon — build, two bugs, and a fix

*Maintainer-facing notes.* This documents getting **[DXMT](https://github.com/3Shain/dxmt)** to run
**The Elder Scrolls V: Skyrim Anniversary Edition** (GOG, runtime 1.6.1179) on macOS / Apple Silicon
from a **from-source DXMT build**, and two issues found along the way. It is written so the DXMT
maintainers can (a) check whether the analysis is correct, (b) tell me the canonical dev/repro setup,
and (c) decide whether either fix is worth upstreaming. **I'm happy to re-run anything on your behalf.**

Everything below assumes a legally-owned copy of the game; no game assets are redistributed.

## TL;DR
- DXMT renders Skyrim AE to **interactive gameplay** on Apple Silicon, but only after working around
  one crash and fixing one rendering bug.
- **Finding #1 — reference-count under-count → use-after-free** during engine init. The engine releases
  a resource/view once more than DXMT counts; DXMT frees it (private refcount hits 0) while the engine
  still holds a stale pointer → `__cxa_pure_virtual`. I have a **leak-based workaround that proves the
  diagnosis** but is *not* a real fix. **I'd like guidance on the correct fix.**
- **Finding #2 — writable depth/stencil attachments aren't hazard-tracked** → cascaded shadow maps read
  stale depth → **frozen/flickering shadows**. I have what looks like a **correct, minimal fix** and
  would value a review. Patch: [`files/dxmt-finding2-depth-write-hazard.patch`](files/dxmt-finding2-depth-write-hazard.patch).

**Primary artifact: a replayable apitrace** of the crash on **stock DXMT 0.80** —
`skyrim-dxmt080-enginecrash.trace` ([capture recipe](dxmt-apitrace-capture.md)). The maintainers can
`apitrace replay` it on their own reference stack to confirm the crash *independent of my host Wine*;
the source-level analysis below is supporting context, not a proposed fix.

**Confounders controlled:**
- Crash reproduces on the **stock DXMT 0.80 release** (not just my from-source build / dev commit
  `v0.80-27-g0606575`) — so it isn't a build artifact.
- **Vanilla Skyrim**, zero mods — no Community-Shaders-style variable.
- Host Wine is **FOSS CrossOver-sources**, which DXMT's own install guide explicitly sanctions
  ("a FOSS CrossOver Wine 24+ built from the sources is sufficient") — not an off-book choice.
- The `system32` DLL copies are a **required** hand-rolled-install step (without them the game can't
  locate `d3d11.dll` → `c0000135`), the equivalent of CrossOver's integration — not a tracing artifact.
- The one variable I can't eliminate myself (from-source vs official CrossOver patches) is exactly what
  replaying the trace on their reference settles.

---

## 1. Environment & build (what I'd love you to sanity-check)

**Host:** macOS 26, Apple Silicon (M-series), Xcode 26.5 + Metal Toolchain component.

**DXMT built from source** following `docs/DEVELOPMENT.md` + `.github/workflows/ci.yml`:
- Custom **x86_64 LLVM 15.0.7** (`-DLLVM_TARGETS_TO_BUILD="" -DLLVM_BUILD_TOOLS=Off
  -DCMAKE_OSX_ARCHITECTURES=x86_64`), **llvm-mingw 20251216**, **meson 1.11**, **ninja**, Metal Toolchain.
- 3Shain **Wine fork `v8.16-3shain`** as `-Dwine_install_path` (the `winemetal.so` reference target).
- `meson setup --cross-file build-win64.txt -Denable_nvapi=true -Denable_nvngx=true
  -Dnative_llvm_path=<llvm> -Dwine_install_path=<wine-fork> build --buildtype debugoptimized` → builds
  the x86_64 PE DLLs + `winemetal.so` cleanly.

**The one place my setup likely diverges from yours — and my first question:**
I do **not** run on the `v8.16-3shain` fork. Skyrim AE's engine-init has a separate Wine-7.x crash that
is only resolved on **Wine 11**, so I run DXMT on a **from-source CrossOver-26 Wine (Wine 11.0)** build
instead (details in [`dxmt-v2-investigation.md`](dxmt-v2-investigation.md)). The DXMT-built
`winemetal.so` (linked against the fork's `winemac.so`/`ntdll.so`) **loads and resolves fine on
CrossOver-26's `winemac.so`** — both export `macdrv_functions`. **Is running the fork-built DXMT on a
newer Wine supported/expected, or is there a recommended host Wine for engines that need >8.16?**

Skyrim-specific setup (not DXMT-related): short install path to dodge an asset-path buffer overflow;
native Media Foundation + XAudio2 for audio. Game reaches the main menu and gameplay.

---

## 2. Finding #1 — reference under-count → use-after-free (engine-init crash)

**Symptom.** During engine init (right after the first pipeline compiles), DXMT's own
`__cxa_pure_virtual` (`src/d3d11/d3d11.cpp:250`) traps. Backtrace frame 1 is Skyrim calling
`Release()` (`call *0x10(%rax)`, COM vtable slot 2) on an object whose vtable slot is the pure-virtual
stub — i.e. the object was already destroyed.

**Identified object.** Instrumenting `__cxa_pure_virtual` to read the Itanium RTTI of `this` named it:
`dxmt::TDynamicLinearTexture<tag_texture_2d>` (reported via the abstract base `D3D11ResourceCommon`,
i.e. the vptr had been reset by destruction). After parking resources alive, the crash *moved* to
`dxmt::D3D11ShaderResourceView` — so the engine over-releases **both resources and views.**

**Refcount trace** (instrumenting `ComObject::AddRefPrivate`/`ReleasePrivate`, `this=0x7E1D9A10`):
```
ARP priv 0->1  (ComObject::AddRef — engine's first public ref)
ARP priv 1->2  (the texture's SRV takes a private ref)
   ... object lives across the whole load (>4096 later object creations) ...
RLP priv 2->1  caller = TDynamicLinearTexture::SRV::~SRV()   (SRV released first)
RLP priv 1->0  caller = ComObject::Release()  -> delete this (public refcount hit 0)
-> engine Releases the texture ONE more time -> __cxa_pure_virtual
```
The object is created early, **held for the entire session**, and released **one time too many** at
teardown. `ComObject` deletes on `m_refPrivate == 0`; the only internal holder (the SRV) is released
first, so the surplus engine `Release()` lands on freed memory.

**What I tried, and what it tells us:**
- **Park every resource/view alive** (extra `AddRefPrivate` in `TResourceBase` / `TResourceViewBase`
  ctors) → **no crash, Skyrim renders to gameplay.** This is a **leak**, not a fix — see
  [`files/dxmt-finding1-refcount-workaround.patch`](files/dxmt-finding1-refcount-workaround.patch).
- **Bounded deferral** (free the oldest after N=4096 creations) → **crash returns.** So the stale
  reference's lifetime is **unbounded in object-creation terms** — no fixed count is safe. The leak is
  the only count-based variant that survives.

**My read (please correct me):** because the object lives the whole session and gets exactly one extra
release, this looks less like a transient cleanup double-release and more like **DXMT under-counting a
reference the engine legitimately holds** — a path that hands the engine the resource a second time
(`CreateX` + `QueryInterface`, `GetBuffer` twice, or a view→resource query) **without an `AddRef`**.
The `ComObject` comment notes this dual-refcount exists for engines that "steal internal references";
DXVK keeps such objects alive via **usage-tied** internal references (bindings / command buffers,
released on GPU completion), not an unbounded leak.

**Questions for you:**
1. Is this expected reference-stealing that should be absorbed by a **usage-tied lifetime** (à la DXVK),
   or a concrete **missing `AddRef`** we can locate? Where would you expect the fix to live?
2. Is `TDynamicLinearTexture` (dynamic linear 2D texture) handled differently from other resources in a
   way that would explain why its protective/internal reference doesn't outlive the engine's pointer?

---

## 3. Finding #2 — writable depth/stencil not hazard-tracked → frozen shadows

**Symptom.** Cascaded shadow maps are **frozen at the first frame** (initial shadows persist while the
camera moves) with intermittent flicker. No Metal validation errors during gameplay; no DXMT warnings.

**Root cause.** In `SwitchToRenderEncoder()` (`src/d3d11/d3d11_context_impl.cpp`), the depth/stencil
attachment is registered for hazard tracking with a **hardcoded `ResourceAccess::Read`** (with a
`// TODO: ...should know more about store behavior`), even though `store_action = WMTStoreActionStore`
and the DSV is writable. Everywhere DXMT *writes* a resource it passes `ResourceAccess::Write`/`ReadWrite`
(color attachments, blit destinations) — that's what makes the tracker synchronize a later read against
the write. So a shadow-map **depth write is untracked**, and the subsequent pass that **samples the
shadow map as an SRV** isn't synchronized against it → it reads stale depth → frozen/flickering shadows.

**Fix** ([`files/dxmt-finding2-depth-write-hazard.patch`](files/dxmt-finding2-depth-write-hazard.patch)):
register each plane as `ReadWrite` when it isn't read-only, using the DSV's `readonly_flags_`
(`bit0 = D3D11_DSV_READ_ONLY_DEPTH`, `bit1 = stencil`):
```cpp
auto access_flag = (dsv.ReadOnlyFlags & 0x1) ? ResourceAccess::Read   // depth plane
                                             : ResourceAccess::ReadWrite;
// ... and (dsv.ReadOnlyFlags & 0x2) for the stencil plane
```

**Result:** shadows now track the scene correctly as the camera moves. A brief (~5–10 s) artifact
remains at scene start, then it's clean — possibly normal shadow-map warm-up and/or a side effect of
the Finding-#1 leak workaround pinning the first frames' resources.

**Questions for you:**
1. Does this look like the right place/way to fix it? Should the `store_action` likewise be conditional
   (`DontCare` for a read-only plane) — or do you intentionally always store?
2. Any concern about over-synchronization (tile memory / load-store) from promoting depth to `ReadWrite`?
3. Is the residual first-5–10 s shadow transient something you'd expect?

---

## 4. How to reproduce / the diagnostic harness

- The object in Finding #1 was named by patching `__cxa_pure_virtual` to capture `this` (Win64 ABI →
  `rcx`) and read its Itanium RTTI (`vtable[-1] → type_info::name()`); the refcount trace adds
  `fprintf` to `ComObject::AddRefPrivate`/`ReleasePrivate`. Both are in
  [`files/dxmt-finding1-refcount-workaround.patch`](files/dxmt-finding1-refcount-workaround.patch)
  (the RTTI dump) — useful if you want to reproduce the diagnosis on a fork build.
- I can provide the full CrossOver-26 Wine build recipe, the prefix, and a one-command launch, or test
  any patch/setup you suggest and report back. Tell me the host Wine you'd prefer I use.

## Status summary
| # | Issue | State |
|---|---|---|
| 1 | Reference under-count → use-after-free (engine-init crash) | Diagnosed; **leak workaround only**; real fix needs maintainer guidance |
| 2 | Writable depth/stencil not hazard-tracked → frozen shadows | **Fix implemented & confirmed**; review requested |
| — | First-5–10 s shadow transient | Open; minor; possibly warm-up and/or the #1 workaround |
