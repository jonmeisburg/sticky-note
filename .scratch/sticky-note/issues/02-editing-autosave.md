# 02: Editing + autosave

**What to build:** The note becomes a real editor: clicking anywhere in the note's text takes keyboard focus (with a visible editing cue), keystrokes edit the note, and everything typed is saved automatically to the state document with light debouncing. Editing ends either by clicking away from the note (focus moves to another window) or pressing Escape. Text longer than the note's visible area scrolls inside the note, so no text is ever unreachable or clipped.

**Amendment (2026-08-31):** the interaction state machine and the layer-shell focus plumbing are gone — the note is a real window, so editing *is* native focus semantics (editing = the text area holds active focus; commit = focus loss or Escape). What remains of this ticket is verifying that behavior and the autosave contract. The original "primary flagged risk" (background-layer keyboard focus) was deleted along with the background layer.

**Blocked by:** 01 (The note exists).

**Status:** ready-for-agent

- [ ] A clean click on the note's text begins editing: text cursor appears, editing cue visible.
- [ ] Typing lands in the note and only in the note — a real window only receives keystrokes when the compositor has focused it, same as every other window.
- [ ] Changing the note's text persists to the state document automatically during the edit, with no explicit save action; debounced so bursts of typing don't thrash the disk.
- [ ] Clicking away from the note (focus moves to another window) commits editing.
- [ ] Pressing Escape commits editing and drops the cursor while the window keeps focus.
- [ ] After a reboot, all typed text is present and in place.
- [ ] When text exceeds the visible area, the note scrolls internally (word-wrapped, no horizontal scrollbar), and the end of the text is reachable.
- [ ] Autosave does not lose the final keystrokes of an editing session at commit time.
- [ ] State-model save/load round-trip tests pass (the seam-1 suite).