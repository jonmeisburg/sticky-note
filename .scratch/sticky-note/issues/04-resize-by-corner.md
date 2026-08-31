# 04: Resize by corner

**What to build:** Nothing to build — superseded by the 2026-08-31 spec amendment. The note is a real window, so resizing is native Hyprland behavior: resize with the user's resize bind while floating, or by resizing its tile. The readability size floor survives as a native `minimumSize` on the window (140×140 paper), so an unreadable sliver is impossible by construction. There is no custom corner grip and no resize clamp — tall notes down the screen are achieved by stretching the window.

**What remains to verify:**

- [ ] Resizing (float or tile) works with the user's native binds, in both dimensions, down and across.
- [ ] The window cannot be resized below the minimum size in either dimension (native floor).
- [ ] A resized note's size persists: after a restart the note spawns at the last recorded size (tiling may then reshape it, which is correct).
- [ ] Editing (text click) and autosave are unaffected by resize; the text re-flows with word wrap.