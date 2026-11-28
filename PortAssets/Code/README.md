# Recovered GML reference

Two sets of decompiled GameMaker code are kept here:

- `Reference/` — Fredsweeper/minigame GML with the iOS touch-control edits
  (sticky FLAG toggle, tap-to-chord, hold-to-chord, drag tracking, queue-based
  tile clearing). This is the source of truth for the native port. Do not
  overwrite it with a fresh decompile.
- `Vanilla-2.2.2/` — pristine decompilation of the same seven code entries from
  the recovered 2.2.2 `data.win`. Use it only to see what the upstream game
  does; it does not contain the touch edits.

`Scripts/export-port-assets.ps1` regenerates the vanilla set and
`Scripts/import-port-assets.ps1` copies it here. The `Reference/` folder is
never touched by either script.
