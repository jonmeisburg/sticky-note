# 03: Move by drag

**What to build:** Nothing to build — superseded by the 2026-08-31 spec amendment. The note is a real window, so moving it is native Hyprland behavior: float it (the user's float bind), drag it with SUPER+drag or the mouse, or let the tiling engine place it. There is no custom drag gesture, no click-vs-drag threshold, and no drag clamp to keep the note reachable — the compositor already guarantees a window can be moved and found.

**Status:** done

**What remains to verify:** (all verified live 2026-09-01)

- [x] Floating the note and moving it works with the user's native binds. *(live-verified: floated the note via the float toggle (SUPER+T equivalent) → `floating: true`; drag-moved the floating note with SUPER+LMB (its `at` moved from `[3683,31]` to `[4417,-113]`); a tiling workspace move also re-placed it. All through the compositor, no custom gesture.)*
- [x] Moving the note (float or tile swap) never disturbs its text or triggers a spurious save of anything but geometry. *(live-verified: across float → drag → unfloat → tiling round-trip the state document's `text` stayed byte-identical; only `width`/`height` changed (725×790 → 744×804 → 1488×790 → 725×790). A position-only drag wrote nothing — placement is never recorded.)*
- [x] A moved note keeps working: clicking into it still edits, autosave still fires. *(live-verified: after the moves, clicking the note entered editing (it became the active window), a typed marker landed in the note, and the debounced autosave wrote it to disk. Note text was then restored to its prior content.)*

**Position persistence note:** placement is compositor-owned and per-session; the state document records x/y only as loaded/hand-edited values and does not chase live window position. If the user later wants last-float-position restored at spawn, that is a new, explicitly-specced ticket.