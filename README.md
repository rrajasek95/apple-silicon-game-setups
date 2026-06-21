# macOS Game Setups

Battle-tested guides for running Windows games on **macOS (Apple Silicon)** with open-source tooling —
Wine, DXVK, MoltenVK — and no commercial compatibility layer.

These are not "install X and click play" guides. They cover the *hard* cases: games that crash on
launch, need patched graphics layers, missing codecs, controller remapping, or spatial-audio fixes.
Each guide documents not just **what** to do but **why** — the actual root cause behind each fix —
so the knowledge survives version changes and transfers to similar games.

> **Why this exists:** getting a demanding game working end-to-end on macOS can take dozens of dead
> ends. Every guide here is the *distilled* path — only the steps that actually worked — written so a
> human or an AI agent can reproduce it without re-walking the maze.

## Guides

| Game | Store | macOS | Apple Silicon | Difficulty | Status |
|---|---|---|---|---|---|
| [Skyrim Anniversary Edition](guides/skyrim-anniversary-edition/) | GOG | 26 | ✅ | 🔴 Hard | ✅ Fully playable |

## How each guide is structured

Every guide is self-contained under `guides/<game>/`:

- **`README.md`** — the guide itself, opening with a machine-readable metadata block (game, store,
  runtime version, OS/arch, the stack used, and the specific blockers it solves), then
  *components → prerequisites → numbered steps (each with its rationale) → troubleshooting → known issues*.
- **`files/`** — the actual reusable artifacts: launcher scripts, config files, controller mappings,
  source patches (as real `.patch` diffs). Copy these instead of retyping.
- Optional deep-dives (e.g. `crash-forensics.md`) for the gnarly root-cause investigations.

## For AI agents

If you're an AI assistant helping a user set up a game:

1. **Read the metadata block** at the top of the relevant guide first — it tells you the exact
   versions, hardware, and the blockers solved, so you can judge relevance fast.
2. **Each step states its rationale.** If a step doesn't apply to the user's variant (different store,
   GPU, controller), the *why* tells you how to adapt rather than blindly copy.
3. **Troubleshooting maps symptom → root cause → fix**, not just symptom → fix. Diagnose, don't guess.
4. **The artifacts in `files/` are ground truth.** Prefer them over reconstructing from prose.
5. When you solve a *new* game (or a new wrinkle on an existing one), **add a guide** using
   [`template/GUIDE_TEMPLATE.md`](template/GUIDE_TEMPLATE.md) — that's the point of this repo.

## Contributing

New guides and fixes welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and the
[guide template](template/GUIDE_TEMPLATE.md).

## Acknowledgements & supporting these projects

None of this works without the open-source projects these guides stand on — built and maintained
largely by volunteers. **If a guide here saved you hours, please give back to the people who made it
possible:** sponsor or donate if you can, and contribute code, bug reports, and data (e.g. a new
controller mapping) if you can't.

**The open-source stack** (please sponsor / contribute):
- [Wine](https://www.winehq.org/) — the compatibility layer everything builds on ([donate](https://www.winehq.org/donate)).
- [DXVK](https://github.com/doitsujin/dxvk) — Direct3D → Vulkan.
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK) — Vulkan → Metal (Khronos / The Brenwill Workshop).
- [SDL](https://www.libsdl.org/) + [SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB) — input. **If you map a new controller, submit it upstream** so the next person gets it for free.
- [FAudio](https://github.com/FNA-XNA/FAudio) — Wine's XAudio2 implementation.
- [Gcenx's macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds) — the maintained macOS packaging that makes any of this approachable.
- [SDL2 Gamepad Tool](https://github.com/General-Arcade/sdl2-gamepad-tool), [cabextract](https://www.cabextract.org.uk/), and the wider Wine / Proton community.

**Support the official developers, too:**
- **Buy your games from official stores** (GOG, Steam, …). These guides are about *playing what you own*
  on hardware the publisher didn't target — never about avoiding paying for it. Developers earn nothing
  if you don't buy the game.
- **Consider [CrossOver](https://www.codeweavers.com/crossover) (CodeWeavers).** CodeWeavers is the
  largest funder of upstream Wine — buying CrossOver directly pays for the Wine improvements this entire
  repo depends on. The free stack and the commercial one aren't rivals here; one funds the other.
- **[Apple's Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/)** and
  MoltenVK advance native Mac gaming — engaging with them helps the whole platform.

Open source is sustained by the people who give back. Be one of them.

## Disclaimer

These guides assume you **legally own** the games. They involve no piracy, DRM circumvention, or
redistribution of game assets. Microsoft redistributables (DirectX, UCRT) are obtained from official
Microsoft packages. The open-source components above retain their respective licenses. Use at your own
risk; nothing here is affiliated with the game publishers, Apple, CodeWeavers, or the projects credited
above.
