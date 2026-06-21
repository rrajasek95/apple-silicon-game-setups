<!--
Copy this file to guides/<game-slug>/README.md and fill it in.
Keep the metadata block — it's what lets humans and AI agents assess relevance at a glance.
Golden rule: every step states WHY, and troubleshooting maps symptom → root cause → fix.
-->

# <Game Name> on macOS (Apple Silicon)

```yaml
game: <Full Game Name>
store: <GOG | Steam | Epic | disc | ...>
game_version: <runtime/build version, e.g. 1.6.1179>
os: macOS <version>
arch: <Apple Silicon | Intel>
status: <fully playable | playable-with-caveats | partial | wip>
difficulty: <easy | moderate | hard>
stack: [Wine <ver>, DXVK <ver>, MoltenVK <ver>, ...]
blockers_solved:
  - <one line per non-obvious problem this guide solves>
last_verified: <YYYY-MM-DD>
```

One-paragraph summary of the result and the overall approach.

## Components
| Layer | What | Version / source |
|---|---|---|
| Engine | Wine ... | ... |
| ... | ... | ... |

Briefly justify *why each component* (especially any non-default/patched ones).

## Prerequisites
- ...

## Steps
For each step: the commands, then **why** it's needed (the root cause it addresses).

### 1. ...
### 2. ...

## Key paths
- Launcher / prefix / config / artifacts.

## Tuning / troubleshooting
Map **symptom → root cause → fix** (not just symptom → fix):
- **<symptom>** — <root cause> → <fix>.

## Known issues
- <what's not perfect, with the reason and any workaround>.

## Files
List what's in `files/` and what each is for.
