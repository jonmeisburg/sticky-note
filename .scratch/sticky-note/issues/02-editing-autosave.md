# 02: Editing + autosave

**What to build:** The note becomes a real editor: clicking anywhere in the note's text takes keyboard focus (with a visible editing cue), keystrokes edit the note, and everything typed is saved automatically to the state document with light debouncing. Editing ends — and focus is released back to the rest of the desktop — either by clicking away from the note or pressing Escape. Text longer than the note's visible area scrolls inside the note, so no text is ever unreachable or clipped. This ticket carries the project's primary flagged risk: taking keyboard focus only when deliberate, and releasing it reliably.

**Blocked by:** 01 (The note exists).

**Status:** ready-for-agent

- [ ] A clean click on the note (press with no movement) begins editing: text cursor appears, editing cue visible.
- [ ] Typing lands in the note and only in the note; keystrokes outside the note are never captured while idle.
- [ ] Changing the note's text persists to the state document automatically during the edit, with no explicit save action; debounced so bursts of typing don't thrash the disk.
- [ ] Clicking away from the note commits editing and returns keyboard focus to the rest of the desktop.
- [ ] Pressing Escape commits editing and releases focus.
- [ ] After a reboot, all typed text is present and in place.
- [ ] When text exceeds the visible area, the note scrolls internally (word-wrapped, no horizontal scrollbar), and the end of the text is reachable.
- [ ] Autosave does not lose the final keystrokes of an editing session at commit time.
- [ ] State-model save/load round-trip tests pass; interaction state-machine tests pass for both commit paths (click-away, Escape).