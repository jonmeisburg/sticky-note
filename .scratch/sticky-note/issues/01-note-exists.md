# 01: The note exists

**What to build:** The first working sticky note: an Omarchy plugin (`sticky-note`) that renders a single yellow note on the desktop background layer — always visible on the desktop, always behind normal windows, never focus-hungry. Text, position, and size come from a persisted state document; if it's missing, the note uses sane defaults (empty text, default size and position). If the file is corrupt or malformed, the note falls back to the same safe defaults rather than failing to launch. The plugin also launches automatically at login via the documented autostart hook.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] A note appears on the desktop, sized ~300×300, at the top-left, styled: paper-yellow body, slightly rounded corners, subtle shadow.
- [ ] The note sits behind all normal application windows and never takes focus on its own.
- [ ] Text shown in the note comes from the persisted state document; a hand-edited state file's text and geometry appear after a restart.
- [ ] With no state file present, the note shows defaults and creates one on first save path (not required to save yet).
- [ ] A corrupt/truncated/malformed state file results in safe defaults and a normal-looking desktop, with no crash and a recoverable (not destructively overwritten) original file.
- [ ] The note reappears automatically at login.
- [ ] State-model load tests pass, covering: defaults when absent, and safe fallback on malformed input.
- [ ] Plugin hot-reloads on code changes (edit → visible result live).