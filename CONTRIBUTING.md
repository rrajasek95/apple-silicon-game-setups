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

1. **State the rationale for every step.** Each step must describe the specific failure it prevents or
   the mechanism it depends on, not only the action to take. State versions and behaviours, not vague
   claims, so the step stays correct when tooling changes and transfers to similar games.
2. **Write troubleshooting as symptom → root cause → fix.** For every issue, give the observable
   symptom, the underlying cause, and the fix that follows from that cause. Do not list a fix without
   its cause.
3. **Keep only the verified path in the numbered steps.** Steps must contain only actions that are part
   of the working setup. Record approaches that were tried and failed in the compatibility matrix or a
   short "what didn't work and why" note — not in the steps.
4. **Pin exact versions and record verification.** Give specific versions in the metadata block and a
   `last_verified` date. When a particular version is required (not merely what you used), say so and
   explain why in the compatibility matrix.
5. **Do not include game assets or DRM circumvention.** Assume the reader legally owns the game. Do not
   commit copyrighted game files, instructions to extract them, or any DRM bypass.
6. **Link third-party redistributables; do not vendor them.** Obtain Microsoft and other redistributables
   (DirectX, UCRT, codecs) from their official sources and link to them. Do not commit these binaries;
   the `.gitignore` blocks the common extensions.

## Generalize machine-specifics

Replace your home dir with `$HOME`, hardware/prefix UUIDs and absolute install paths with clearly
marked placeholders (`<your GOG install dir>`). The guide should work on someone else's machine.
