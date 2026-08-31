# 04: Resize by corner

**What to build:** The note can be stretched: dragging its bottom-right corner resizes it in height and width — tall notes down the screen are explicitly supported — with a visible hover affordance showing the corner is grabbable, and a minimum-size floor so the note can't be resized into an unreadable sliver. Size persists. The gesture classifier now distinguishes press intent by region: body → move (ticket 03), corner → resize, no movement → edit (ticket 02).

**Blocked by:** 03 (Move by drag).

**Status:** ready-for-agent

- [ ] Dragging the bottom-right corner resizes the note live while dragging.
- [ ] The resize grip shows a hover affordance (cursor and/or visual highlight) so the affordance is discoverable.
- [ ] Resizing cannot go below a sensible minimum size in either dimension.
- [ ] The note's size persists across reboot.
- [ ] Editing (body click) and moving (body drag) are unaffected by the grip's presence.
- [ ] Gesture-classifier tests pass for resize-region classification; minimum-size floor is verified as pure logic.