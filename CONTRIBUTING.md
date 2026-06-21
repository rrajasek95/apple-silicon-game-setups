# Contributing

Guides for new games, fixes to existing ones, and version bumps are all welcome.

## Adding a guide

1. Copy [`template/GUIDE_TEMPLATE.md`](template/GUIDE_TEMPLATE.md) to `guides/<game-slug>/README.md`.
2. Fill in the **metadata block** honestly — versions and `last_verified` matter; they're how readers
   judge whether the guide still applies.
3. Put reusable artifacts (launchers, configs, mappings, `.patch` diffs) in `guides/<game-slug>/files/`
   and reference them from the steps. Don't paste large blobs inline if a file will do.
4. Add a row to the table in the top-level [README](README.md).

## Quality bar

- **Every step states why.** "Set X native" is useless in a year; "Set X native because Wine's builtin
  reports the device as 5.1 and collapses rear audio" survives version changes and transfers to other games.
- **Troubleshooting is symptom → root cause → fix.** Help the next person diagnose, not cargo-cult.
- **Only the path that works.** Cut the dead ends from the final guide (a short "what didn't work and
  why" note at the end is fine if it saves someone time).
- **No game assets, no DRM circumvention.** Microsoft redistributables come from official MS packages;
  link, don't vendor them. Assume the reader legally owns the game.

## Generalize machine-specifics

Replace your home dir with `$HOME`, hardware/prefix UUIDs and absolute install paths with clearly
marked placeholders (`<your GOG install dir>`). The guide should work on someone else's machine.
