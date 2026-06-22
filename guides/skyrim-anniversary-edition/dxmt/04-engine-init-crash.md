# Engine-init crash under DXMT (apitrace)

Vanilla Skyrim Anniversary Edition (GOG, runtime 1.6.1179) crashes during engine init under DXMT,
before the main menu. No mods. The game runs natively on Windows, so this is Mac/DXMT-specific.

## Setup
- MacBook Pro · Apple Silicon · macOS 26
- Host Wine: **FOSS CrossOver-sources 26** (`crossover-sources-26.0.0`, Wine 11.0), built from source — *not* commercial CrossOver
- **DXMT 0.80** (release; installed per the guide's non-builtin mode — system32 + `WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b"`)
- apitrace 13.0

Trace: `skyrim-dxmt080-enginecrash.trace` (~170 MB) — sent separately.

## What fails
- Replays through device creation, swapchain, and the first pipeline.
- Then ends at the crash: DXMT aborts in its own `__cxa_pure_virtual` handler when the engine calls `Release()` on a D3D11 object DXMT has already freed — the engine holds one more reference than DXMT counted.
- Object: `D3D11ResourceCommon` (a dynamic texture); shifts to `D3D11ShaderResourceView` once the texture is pinned alive.

## In the trace

Where the over-release lands (call numbers from this capture). The object is a **256×256 dynamic
texture** (`MAP_WRITE_DISCARD`) — **1 create, 0 AddRef, 2 Release**:

```
17534  ID3D11Device5::CreateTexture2D → 0x7e869d20    (refcount 1)
17535  CreateShaderResourceView(0x7e869d20);  then repeated Map(WRITE_DISCARD)
80711  ID3D11ShaderResourceView1::Release(0x7e835f20) = 0
80712  ID3D11Texture2D1::Release(0x7e869d20) = 0       ← last ref dropped; DXMT frees it
80713  ID3D11Texture2D1::Release(0x7e869d20)           ← released again it never held → crash
```

The engine releases the texture once more than it holds. DXVK tolerates this; DXMT frees on `80712`,
so `80713` lands on freed memory.

## Rough stacktrace

Not a precise repro (the trace is that) — just a place to look in DXMT and how Skyrim hits it:

```
EXCEPTION_ILLEGAL_INSTRUCTION (0xC000001D)  — DXMT __builtin_trap

  d3d11.dll     __builtin_trap()
  d3d11.dll     dxmt::__cxa_pure_virtual              src/d3d11/d3d11.cpp:250
  d3d11.dll     IUnknown::Release(resource)           ← already freed; vtable is the abstract
                                                        dxmt::D3D11ResourceCommon, so slot 2
                                                        (Release) is the pure-virtual stub
  SkyrimSE.exe  engine-init resource teardown         (skyrimse +0x1197cf3 … +0xe4b47c)
  kernel32.dll  BaseThreadInitThunk
  ntdll.dll     RtlUserThreadStart
```

- **DXMT:** the dual refcount in `ComObject` (`src/util/com/com_object.hpp`) and the resource's `Release`/`ReleasePrivate` — the object is freed when `m_refPrivate` hits 0.
- **Skyrim:** engine-init teardown releases a stored D3D11 resource once more than it AddRef'd; DXMT had already freed it.

## Bypass (workaround, not a fix)

A protective internal reference on every resource/view
([refcount-workaround.patch](refcount-workaround.patch)) keeps the object alive past the engine's
over-release, so the game runs to gameplay. It's a deliberate leak — it confirms the diagnosis, it is
not the fix.

Detail: [dxmt-skyrim-findings.md](../dxmt-skyrim-findings.md).
