# Live-verification recipe (compositor-driven)

**Purpose:** how to verify a verify-only ticket against the *running* desktop —
drive the note through Hyprland and assert on the state document. There is no
code and no pixels to read; the oracles are `hyprctl` (compositor truth) and
the state file (persistence truth).

**Used by:** tickets 03, 04, 05 — all "verify the native behavior" only, since
the 2026-08-31 amendment made the note a real window (no custom drag/resize
code to exercise). Reusable by any future ticket whose acceptance boxes are
live behaviors rather than code.

**Convention reminder:** a box is ticked only after the behavior is
demonstrated (CLAUDE.md). For these tickets the demonstration is a
compositor sequence + a state-file diff, recorded in the ticket as a
`*(live-verified: …)*` annotation.

---

## 0. Preconditions

- A live Wayland session (Hyprland + omarchy shell): `echo $WAYLAND_DISPLAY`.
- The note window is mapped:
  ```
  hyprctl clients -j | jq -r '.[] | select(.title=="Sticky Note")
    | "at=\(.at) size=\(.size) ws=\(.workspace.id) float=\(.floating) mapped=\(.mapped)"'
  ```
- **If the note window is missing:** the shell owns the plugin (via
  `shell.json` → `Service.qml`). A stray standalone `quickshell -p .` dev
  instance can shadow it. Kill stray dev instances, then `omarchy restart
  shell` (the sanctioned refresh — the symlink isn't hot-reloaded), re-check.
  (Observed 2026-09-01: the note had vanished after a dev instance + reload;
  the exact trigger wasn't diagnosed, but this remedy restored it.)

## 1. Read window state

`hyprctl clients -j` (jq) is the source of truth for placement:
`.title .class .address .at=[x,y] .size=[w,h] .workspace.id .floating .mapped`.
The note's `at`/`size` **change as tiling reshapes it** (a workspace move, a
split toggle, a monitor change) — re-read before every action, don't cache.

## 2. Drive the note — `hyprctl eval` + the `hl.dsp` Lua API

This Hyprland routes every dispatch through a Lua layer, so a bare
`hyprctl dispatch <name> <args>` **fails** (the args break the implicit
`hl.dispatch(...)` call). Run Lua instead with `hyprctl eval "..."`;
dispatchers live under `hl.dsp` (all confirmed `function`-typed).

```lua
-- get the note's window object, then run a dispatcher on the active window
local w for i,x in ipairs(hl.get_windows()) do if x.title=='Sticky Note' then w=x end end
if w then hl.dispatch(hl.dsp.focus({ window = w })) end
```

- **Focus needs the object, not a string.** `hl.dsp.focus({ window = "Sticky
  Note" })` / a class / an address all fail with `window not found`; pass the
  `HL.Window` object from `hl.get_windows()`.
- **Dispatchers act on the ACTIVE window** — focus the note object first.
  Check with `hyprctl activewindow`.
- Useful dispatchers:
  - float/tile toggle:  `hl.dsp.window.float({ action='toggle' })`
  - tiling swap:        `hl.dsp.window.swap({ direction='l'|'r'|'u'|'d' })`
  - tiling move to ws:  `hl.dsp.window.move({ workspace='4', follow=false })`
  - relative resize:    `hl.dsp.window.resize({ x=100, y=0, relative=true })`
  - focus a workspace:  `hl.dsp.focus({ workspace='3' })`
- `print()` inside `eval` does not reach stdout (it logs to quickshell); to
  inspect a value, write it: `local f=io.open('/tmp/x.txt','w') f:write(...) f:close()`.

## 3. Cursor control — `ydotool` (the fiddly part)

- **Daemon first.** ydotool talks to a `ydotoold` at
  `/run/user/1000/.ydotool_socket`. A monitor reconfig can leave a stale
  daemon; if moves misbehave, `kill` it and `nohup ydotoold >/tmp/ydotoold.log 2>&1 &`.
- **The device is REL-only.** `mousemove -a X Y` (absolute) is unreliable on
  it. Use **relative steps + a feedback loop** against `hyprctl cursorpos` —
  that and the note's `at` share the same global coordinate space, so the
  loop converges. Cap each step (~80px), re-read, repeat until within a few
  px (pointer acceleration + screen-edge clamping make one big move jump).
- **Syntax:** `ydotool mousemove -- 12 3` (positional args need `--`) or
  `-x 12 -y 3`.
- **The cursor drifts** (the user's real mouse, other automation). Work in
  short bursts when it's idle; if it wandered, re-read and re-converge.
- **Keys/clicks:** `ydotool key 125:1 125:0` (SUPER down/up; raw keycodes),
  `ydotool click 0xC0` (LMB down+up), `0x40` down, `0x80` up.
- **SUPER+LMB drag of a floating note:**
  `key 125:1` → `click 0x40` → (moveto new position) → `click 0x80` → `key 125:0`.
- **ydotool's keyboard did NOT land in the Quickshell editor** even when the
  note was the active window — type with `wtype` instead (next section).

## 4. Type into the note — `wtype`

```
wtype "TEXT"
```
Uses the Wayland virtual-keyboard protocol; reaches the focused editor where
ydotool's keys didn't. **Caveat:** this build typed the *literal word*
"backspace" for `wtype backspace` (no special-key mapping). So to restore
exact text, write the file (section 6), don't backspace.

## 5. Assert — the state file is ground truth

`F=~/.config/sticky-note/note.json`. Capture a baseline **before** any move:
```
jq -r .text $F > baseline.txt
jq -c '{x,y,width,height}' $F > baseline_geom.json
sha256sum $F
```
After the moves:
- **text undisturbed:** `diff <(jq -r .text $F) baseline.txt` must be empty.
- **geometry-only saves:** `jq -c '{x,y,width,height}' $F` — `x`/`y` stay
  constant (placement is compositor-owned; the doc records x/y only as
  loaded/hand-edited values and never chases live position); only `width`/
  `height` may change. A position-only drag writes *nothing* (mtime unchanged).
- **autosave fired:** a typed marker is in the file within ~1s (debounce is
  500ms). This, with the note active, is the real proof of edit+autosave.
- The idle-vs-edit face is **not** reliably OCR-able (rendered bold vs raw
  `**markers**` reads the same to tesseract); don't use a screenshot to prove
  edit mode — use the marker-reaches-file test. (`grim -o <monitor>` /
  `grim` for a global grab, `tesseract` if you must look.)

## 6. Restore + settle (leave the user's note as found)

Write the exact baseline text back (keep the current geometry — geometry is
observed, never driven), let the model's watcher adopt it, then commit the
note to idle:

**Write while the model is clean.** The model adopts an external file write
only while *not* dirty (`adopt` returns early when `_dirty`); geometry churn
(a resize, a tiling shuffle) keeps it dirty, and a dirty model re-saves its
own text over your write within the debounce. So confirm the file mtime is
stable (no re-writes) before writing, then re-check the diff:
```
python3 - <<'PY'
import json
f="/home/jmeisburg/.config/sticky-note/note.json"
d=json.load(open(f))
d["text"]="**Todo**\n\nTickets 2-5 (code review through each one)\n\n\n\n"  # exact prior text
open(f,"w").write(json.dumps(d,indent=2)+"\n")
PY
sleep 1   # watcher adopts the external edit
diff <(jq -r .text $F) baseline.txt   # must be empty
```
Then focus a non-note window (e.g. the `foot` terminal) so the note commits
to its idle face. Confirm `hyprctl activewindow` is no longer the note.

## 7. Test suite

```
./tests/run.sh                     # node logic + quickshell harness (needs Wayland)
node --test tests/*.test.mjs       # logic only, no display
```

## Throwaway state (never point at the real note by accident)

```
STICKY_NOTE_STATE=/tmp/note.json quickshell -p .
```
The `STICKY_NOTE_STATE` override is what keeps dev/tests from clobbering the
user's `~/.config/sticky-note/note.json`.

---

## review-03 (this ticket) — verify-only, no code findings

No code diff to review (the amendment removed the custom-drag design).
**Standards:** clean — one cosmetic nit (the `**Status:**` line placement
under the "what remains to verify" header), fixed inline in the ticket.
**Spec:** all three acceptance boxes are backed by live demonstration (float +
SUPER+LMB move; text byte-identical with geometry-only saves across the
float→drag→unfloat→tiling round-trip; click-in edit + autosave marker on
disk, text then restored). Nothing to remediate.

## review-04 (this ticket) — verify-only, no code findings

No code diff to review (the amendment removed the custom-resize design; the
readability floor is the window's native `minimumSize`, already in place).
**Standards:** clean — the ticket's `**Status:** done` line and the
`(all verified live …)` annotation follow the ticket-03 convention.
**Spec:** all four acceptance boxes are backed by live demonstration:
native resize in both dimensions (float drag + tiling re-shape), the native
size floor holding at 140×140 paper under a −5000 shrink, size persistence
across `omarchy restart shell` (recorded size → re-map → tiling re-shape →
write-back, text byte-identical), and edit+autosave re-flowing word-wrap
after a resize. Nothing to remediate.

**Recipe notes (learned driving this ticket):** `hyprctl clients .at` /
`cursorpos` are in a global logical space, but `grim -o <mon>` captures
per-monitor **physical** pixels, and the note's monitor scales (×1.667 here).
So a screenshot crop of the note is `((at.x − mon.x) × scale, at.y × scale)`
— not `at − mon`. The two faces are OCR-distinguishable **only when the text
carries bold markers**: the idle face hides the asterisks ("Todo"), the edit
face shows them ("**Todo**"); for marker-free text the faces are identical
(§5's caveat still holds). And the state model adopts an external file write
only while **clean** (§6); a restore write during geometry churn is re-saved
over, so write in a verified-clean window and measure the JSON text field
directly, not `jq -r .text` (which appends its own trailing newline).