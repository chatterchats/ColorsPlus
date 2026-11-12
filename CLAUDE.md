# ColorsPlus

@docs/agent-rules.md

Read README.md first: what the mod does, its layout and how it's tested.

## Rules for this repo

- The game's own customization data is the only place a color is stored. Never call save
  functions or touch save files.
- Draft on the preview; write the real character or weapon only on Apply. Refuse unrecognized
  layouts instead of guessing.
- Re-find objects by name and check them before every step; never cache a widget or fragment
  across frames without validating it.
- Every new script must be loaded from `main.lua` (directly or through another module), or the
  reachability test fails.
- Recovery journals replay only within the game session that wrote them.
