# 03: Move by drag

**What to build:** Nothing to build — superseded by the 2026-08-31 spec amendment. The note is a real window, so moving it is native Hyprland behavior: float it (the user's float bind), drag it with SUPER+drag or the mouse, or let the tiling engine place it. There is no custom drag gesture, no click-vs-drag threshold, and no drag clamp to keep the note reachable — the compositor already guarantees a window can be moved and found.

**What remains to verify:**

- [ ] Floating the note and moving it works with the user's native binds.
- [ ] Moving the note (float or tile swap) never disturbs its text or triggers a spurious save of anything but geometry.
- [ ] A moved note keeps working: clicking into it still edits, autosave still fires.

**Position persistence note:** placement is compositor-owned and per-session; the state document records x/y only as loaded/hand-edited values and does not chase live window position. If the user later wants last-float-position restored at spawn, that is a new, explicitly-specced ticket.