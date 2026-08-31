# 05: Hardening + definition of done

**What to build:** Close out v1 by hardening the edges the happy path doesn't hit, and verifying the whole product against the spec's definition of done. Specifically: a saved position or size that falls off-screen (monitor change, resolution change) is clamped back on-screen at load so the note can never strand itself; a session-stability pass confirms the note runs without crashing or leaking over long uptime; and the full acceptance checklist is walked through manually, start to finish.

**Blocked by:** 01 (The note exists), 02 (Editing + autosave), 03 (Move by drag), 04 (Resize by corner).

**Status:** ready-for-agent

- [ ] A state file pointing somewhere off-screen (or at an absurd position/size) clamps back on-screen at load; no crash, note reachable.
- [ ] After monitor change / resolution change, the note is still visible and usable after its next load.
- [ ] Extended-use stability pass: no crash, no resource growth, no data loss across a long session with the note idle, edited, moved, and resized repeatedly.
- [ ] Full definition-of-done checklist from the spec passes, walked through manually and recorded in this ticket: appears on login with saved text/place/size; click to type with continuous autosave; corner-drag resize; drag to move; scrolls when full; sits behind windows; never steals focus unprompted.