# 01: The note exists

**What to build:** The first working sticky note: an Omarchy plugin (`sticky-note`) that opens a single yellow note as a **real, compositor-managed window** — it tiles alongside the user's windows, can be floated/moved/resized with native Hyprland binds, and is focused like any other window. Text and size come from a persisted state document; if it's missing, the note uses sane defaults (empty text, ~300×300 spawn size). If the file is corrupt or malformed, the note falls back to the same safe defaults rather than failing to launch. The plugin launches automatically at login via the documented enable-in-shell.json flow.

**Amendment:** originally specced as a background-layer surface "behind all windows"; changed to a real window on 2026-08-31 after live use showed the user's tiled-windows workflow made a background-layer note invisible and unclickable (see the spec amendment).

**Blocked by:** None (can start immediately).

**Status:** done

- [x] A note window opens, spawns ~300×300, styled: paper-yellow body, slightly rounded corners, subtle shadow.
- [x] The note is a normal Hyprland client: it tiles alongside existing windows, never buried behind them, and can be floated/moved/resized with the user's native binds.
- [x] Text shown in the note comes from the persisted state document; a hand-edited state file's text appears after a restart.
- [x] The note's size is recorded back from the compositor and restored at next spawn; a hand-edited size takes effect the same way.
- [x] With no state file present, the note shows defaults and creates one on first save (not required to save yet).
- [x] A corrupt/truncated/malformed state file results in safe defaults and a normal-looking desktop, with no crash and a recoverable (not destructively overwritten) original file preserved as `note.json.invalid-*`.
- [x] The note reappears automatically at login (enabled in `shell.json`; the shell loads the service at startup).
- [x] State-model load tests pass, covering: defaults when absent, and safe fallback on malformed input.
- [x] Iteration loop verified: standalone `quickshell -p .` hot-reloads on save; the installed instance is refreshed with `omarchy restart shell` (the sanctioned mechanism; `rescanPlugins` proved unreliable).
- [x] Visual confirmation by the user's own eyes: paper look, shadow, editing cue, no visual glitches.