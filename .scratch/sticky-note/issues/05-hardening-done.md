# 05: Hardening + definition of done

**What to build:** Close out v1 by hardening the edges the happy path doesn't hit, and verifying the whole product against the spec's definition of done. Specifically: a saved position or size that falls off-screen (monitor change, resolution change) is clamped back on-screen at load so the note can never strand itself; a session-stability pass confirms the note runs without crashing or leaking over long uptime; and the full acceptance checklist is walked through manually, start to finish.

**Blocked by:** 01 (The note exists), 02 (Editing + autosave), 03 (Move by drag), 04 (Resize by corner).

**Status:** ready-for-agent

**Known gap (2026-08-31, recorded not fixed):** the window is created before the async state load completes, so spawn sizing (`NoteWindow`'s `Component.onCompleted`) always reads defaults — the persisted doc size never applies at spawn. Inert in practice while the note auto-tiles (the compositor reshapes it at map anyway, and the post-load re-sync records what it settled on), but it means the doc's width/height record the last session's observed size, not the next session's spawn size. A fix would have to apply the doc size only when no compositor reshape has happened yet — otherwise it would fight tiling.

- [x] **Startup race (fixed 2026-08-31):** the spawn→tile geometry burst could arrive before the model's async file read and flush defaults over a note the model had never read — a data-loss path, found live. Fixed in the model (`NoteStateModel.qml`): nothing is written before the first read completes, and the first read adopts the disk document unconditionally; the view holds geometry syncs until the read lands and re-syncs once after. Regression-tested in `tests-harness.qml` ("a save before the first read cannot clobber the file").
- [x] **Superseded by the real-window amendment (closed 2026-09-01):** the compositor owns placement, so on-screen stranding is no longer our failure mode and x/y clamping was deleted from the codebase in the review cleanup (d0b83b9). Only the size floor survives — enforced by the window's native `minimumSize`, already covered by ticket 04's floor check.
- [ ] After monitor change / resolution change, the note is still visible and usable after its next load.
- [ ] Extended-use stability pass: no crash, no resource growth, no data loss across a long session with the note idle, edited, moved, and resized repeatedly.
- [ ] Full definition-of-done checklist from the spec passes, walked through manually and recorded in this ticket: appears on login with saved text/place/size; click to type with continuous autosave; corner-drag resize; drag to move; scrolls when full; sits behind windows; never steals focus unprompted.