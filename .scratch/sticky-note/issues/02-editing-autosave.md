# 02: Editing + autosave

**What to build:** The note becomes a real editor: clicking anywhere in the note's text takes keyboard focus (with a visible editing cue), keystrokes edit the note, and everything typed is saved automatically to the state document with light debouncing. Editing ends either by clicking away from the note (focus moves to another window) or pressing Escape. Text longer than the note's visible area scrolls inside the note, so no text is ever unreachable or clipped.

**Amendment (2026-08-31):** the interaction state machine and the layer-shell focus plumbing are gone — the note is a real window, so editing *is* native focus semantics (editing = the text area holds active focus; commit = focus loss or Escape). What remains of this ticket is verifying that behavior and the autosave contract. The original "primary flagged risk" (background-layer keyboard focus) was deleted along with the background layer.

**Blocked by:** 01 (The note exists).

**Status:** ready-for-agent

- [ ] A clean click on the note's text begins editing: text cursor appears, editing cue visible.
- [ ] Typing lands in the note and only in the note — a real window only receives keystrokes when the compositor has focused it, same as every other window.
- [x] Ctrl+B with a selection wraps it in bold markers; Ctrl+B again unwraps it (identity round-trip). *(live-verified: wrap `**…**` then unwrap round-trips; also the BoldLogic node suite.)*
- [ ] Ctrl+B with the caret on a word toggles that word (VSCode-style); in open whitespace it inserts empty `**` markers, and pressing it again inside them removes them.
- [ ] While editing, the raw source shows `**markers**`; when editing ends, the idle view renders bold words in bold.
- [ ] Clicking the idle (rendered) view enters editing with the caret at the corresponding spot in the source; clicks land at the end when other markdown makes the position ambiguous.
- [x] BoldLogic node tests pass (the bold seam suite).
- [x] Changing the note's text persists to the state document automatically during the edit, with no explicit save action; debounced so bursts of typing don't thrash the disk. *(harness: debounced autosave writes the new text.)*
- [x] Clicking away from the note (focus moves to another window) commits editing. *(live-verified: focus loss committed + flushed the pending text.)*
- [x] Pressing Escape commits editing and drops the cursor while the window keeps focus. *(live-verified: after Escape, further typing did not land; window stayed the active one.)*
- [x] After a reboot, all typed text is present and in place. *(live-verified via `omarchy restart shell`: the note re-mapped on its own with its saved text intact. A full reboot is the same path — login re-launches the service, which loads the same document.)*
- [ ] When text exceeds the visible area, the note scrolls internally (word-wrapped, no horizontal scrollbar), and the end of the text is reachable.
- [x] Autosave does not lose the final keystrokes of an editing session at commit time. *(harness regression added this session: "a commit flush writes the pending tail immediately".)*
- [x] State-model save/load round-trip tests pass (the seam-1 suite).