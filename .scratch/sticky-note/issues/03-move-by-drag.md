# 03: Move by drag

**What to build:** The note can be arranged: pressing on the note's body and moving it drags the note to any desktop position, while a clean press (movement below the threshold) still begins editing as ticket 02 defined. Movement clears a small pixel threshold before a drag begins, so aimed edit-clicks never shift the note. The new position persists, and dragging keeps the note reachable — the note cannot be dragged fully off-screen.

**Blocked by:** 02 (Editing + autosave).

**Status:** ready-for-agent

- [ ] Press-and-move on the note body drags the note; release leaves it at the new position.
- [ ] A press with movement below the click threshold is still an edit-click, not a drag (threshold behavior from the spec, tunable in one place).
- [ ] The note cannot be dragged with both it and its interactive areas entirely off-screen (the gesture clamp keeps at least a sensible part of the note reachable).
- [ ] The note's position persists across reboot.
- [ ] Gesture-classifier tests pass: sub-threshold movement classifies as click; body movement classifies as move.
- [ ] Position-clamp logic is verified as pure logic (no rendering involved).