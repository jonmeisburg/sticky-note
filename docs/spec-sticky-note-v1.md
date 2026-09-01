# Spec: Sticky Note desktop widget
**Label:** `ready-for-agent`
**Status:** Specified via grilling session 2026-08-31; **amended 2026-08-31** (see bottom: "Amendment — the note becomes a real window")

## Problem Statement

The user keeps notes (reminders, thoughts, task lists) while working. Current options put them in places that competes with attention: terminal prompts (temporary), text editor buffers (buried in a project), or external apps (out of sight, out of mind). The user wants the oldest solution in personal computing: a sticky note stuck to their desktop, always visible on an empty workspace, out of the way when windows cover it, that remembers what they wrote.

## Solution

A single plain-text sticky note that lives on the Hyprland desktop:
- Always present on the desktop, visible behind all normal windows (same layer as the wallpaper behaviorally).
- Click it to type; click away or press Escape to stop typing.
- Drag it anywhere; drag its bottom-right corner to resize it.
- Text, position, and size persist across reboots.
- Looks like a classic paper sticky note, with visual details belonging to the user's desktop theme.

Shipped as an Omarchy plugin (QML/quickshell), the native extension mechanism of the user's desktop.

## User Stories

1. As a desktop user, I want a single always-present sticky note on my desktop, so that my scratch thoughts have a permanent home I never "lose" in an app switcher.
2. As a desktop user, I want the note visible whenever my desktop is visible, so that I can glance at it without hunting for a window.
3. As a desktop user, I want the note to sit *behind* my application windows, so that it never blocks or distracts from active work.
4. As a desktop user, I want the note to never capture focus on its own — launching apps, switching windows, and alt-tabbing must never land my keystrokes in the note, so that typing is always safe.
5. As a notes writer, I want to start editing by clicking anywhere in the note's text, so that there is no "open the note" step — the visible note IS the editor.
6. As a notes writer, I want my typing to land in the note only after I've deliberately clicked it, so that I never type into it by accident.
7. As a notes writer, I want to stop editing by clicking away from the note, so that returning to my actual work is automatic.
8. As a notes writer, I want to stop editing by pressing Escape, so that I can finish without touching the mouse.
9. As a notes writer, I want a visible cue that I am editing vs. not editing (text cursor, focus state), so that I always know where my keystrokes are going.
10. As a notes writer, I want every character I type saved automatically, so that a crash, power loss, or reboot costs me nothing.
11. As a notes writer, I want autosave to be frequent enough that I never think about saving, so that the concept of "saving" disappears.
12. As a desktop user, I want my note's text to still be there after reboot, so that the note outlives my session.
13. As a desktop user, I want the note to reappear on its own at login, in the place and at the size I left it, so that my desktop reassembles itself without me.
14. As a note arranger, I want to drag the note's body to any position on the desktop, so that I can put it where it suits my current task (e.g., top-left).
15. As a note arranger, I want my drag to be distinguished from my click by a movement threshold, so that aiming an edit-click doesn't accidentally move the note.
16. As a note arranger, I want the note's position saved after I move it, so that it stays where I put it.
17. As a note arranger, I want to resize the note by dragging its bottom-right corner, so that I can stretch it down the screen for longer lists.
18. As a note arranger, I want resize to work down and across to any reasonable size, so that "tall note covering the left edge" is achievable.
19. As a note arranger, I want a minimum sensible size floor, so that I can't shrink the note into an unreadable sliver.
20. As a note arranger, I want my resize saved, so that my stretching survives reboot.
21. As a notes reader, I want the note to scroll inside itself when text exceeds its visible area, so that no text is ever hidden unreachably or clipped away.
22. As a notes reader, I want to reach the end of a long note by scrolling, so that a page-long list is as usable as a three-word reminder.
23. As a notes reader, I want the note to show plain text with word wrap, so that paragraphs read naturally without horizontal scrolling.
24. As a desktop user, I want the note to look like a classic paper sticky note (warm yellow, dark text, slightly rounded corners, subtle shadow), so that it reads instantly as "note" and pops as an object against my dark desktop.
25. As a desktop user, I want the note's controls (scrollbar, resize handle) to use my desktop theme's palette, so that the note belongs to my setup even while the paper yellow stays classic.
26. As a desktop user, I want soft near-black text rather than pure black, so that text stays comfortable over long sessions.
27. As a desktop user, I want the note at a sensible default size and position on first run (before I've arranged it), so that v1 works before any configuring.
28. As a tinkerer, I want the note's persistent state in a dedicated user-level config location, so that Omarchy updates never wipe my notes.
29. As a tinkerer, I want the note stored in a plain, human-readable format, so that I can inspect or hand-repair it in a terminal.
30. As a tinkerer, I want the note to load sanely from a corrupted or malformed state file, so that a truncated file means a lost note, not a broken desktop.
31. As a tinkerer, I want the plugin hot-reloadable (edit code, see the result live), so that iterating on it is fast and learning is low-friction.
32. As a tinkerer, I want a resizable-corner affordance to be visible on hover, so that the resize affordance is discoverable without documentation.
33. As a desktop user, I want the note process to be a stable part of my long-running desktop session, so that it never crashes my shell or leaks resources over days of uptime.
34. As a desktop user, I want the note confined to a single screen and to re-appear on screen if a saved position falls off-screen (e.g. monitor change), so that it can never strand itself.

## Implementation Decisions

**Platform: Omarchy quickshell plugin.** Built as a QML plugin in the user's Omarchy plugin directory (id `sticky-note`, not using the reserved `omarchy.` prefix), installed via the documented drop-in + enable flow. This was chosen over a standalone Python/Qt app on facts: the standalone path has no layer-shell binding available on this machine (positioning on the Hyprland desktop would require FFI into a C lib), while the plugin path gets persistence, theming, text editing, and layer management from patterns already shipping in the install. This decision came from a repo-wide capability investigation. *(Prototype-grade facts, not snippets.)*

**Module shape — two logic modules and one view.** The design isolates exactly two seams (grilling session, confirmed by the user):
- *Note state model* — a single serializable state unit: text, x, y, width, height. Owns load, save, and file-watch-reload. This is the highest seam in the codebase.
- *Interaction state machine* — pure logic for `idle → editing → committed` transitions and gesture classification (press; movement below threshold → edit-click; movement + region → drag-body vs drag-resize). Consumes synthetic pointer events; knows nothing about rendering.
- The *view layer* binds both to QML (layer-shell panel, text area, borders) and contains no decisions of its own.

**Persistence.** State persists to a persistent user-config directory (survives OS/package updates, distinct from share-level system files), in one JSON document holding text and geometry together. Autosave is a continuous pattern, not a "save" concept: change → write, with light debouncing for typing bursts. The model reacts to external file changes (watching) so that state and file can never silently diverge.

**Layering and focus.** The note renders on the desktop background layer, matching the shipped wallpaper/background plugin's pattern. Keyboard focus is *not* held persistently: the note requests keyboard focus only when editing begins (click) and releases it on commit (click-away or Escape). The exact focus-handling wrinkle is flagged as the build's primary technical risk and is expected to absorb iteration.

**Gesture thresholds.** Click-vs-drag disambiguation via a small pixel movement threshold (drag only begins after movement exceeds it); threshold exposed as a single tunable constant so feel can be adjusted in one place. Resize grip lives at the bottom-right corner (with hover affordance).

**Limits and safety.** Size floor of a sensible minimum (prevents unreadable sliver states); saved positions are clamped back on-screen at load (handles monitor changes); a malformed/corrupt state file falls back to defaults (fresh empty note in default position) rather than failing to launch.

**Look.** Paper yellow (~`#F7D66E` family) body, near-black (`#1A1A1A`) sans-serif text, ~6px rounded corners, subtle shadow, chrome details (scrollbar, grip, borders) sourced from the theme palette. Initial size ~300×300, initial position top-left. A deliberate decision, recorded: the paper yellow is *classic*, not the theme's olive yellow — the theme governs the chrome around it.

**Autostart.** Login launch goes through the documented Omarchy autostart hook. No init-system or systemd-unit of its own — it rides the existing shell lifecycle.

## Testing Decisions

**What makes a good test here:** tests assert *external behavior* only — what's on disk after a mutation, what state is loaded from a given file, what state the machine lands in after a synthetic event sequence, and that committing after editing persists to disk. No test inspects internal variables, widget internals, or renders pixels.

**Seam 1 — state model tests** (highest seam). Given a model pointed at a test file: save → assert file contents reflect the state; mutate file externally → assert model follows; corrupt file → assert defaults survive the load. Every data-loss bug class is catchable here without any UI.

**Seam 2 — interaction state machine tests.** Given synthetic event sequences: a press-without-movement begins editing; a press-with-movement is a drag or resize by region; commit occurs on click-away and on Escape; an edit followed by commit results in a persistence call. This is where the focus-loss and gesture-classification bugs of the kind the grilling risk-flagged get caught.

**Not auto-tested:** rendering and the actual layer-shell focus grab. These are covered by the manual checklist generated from the v1 definition-of-done (login appearance, behind-windows behavior, no focus steal) plus hot-reload's instant visual loop. Rationale: paint assertions on GUI pixels are high-cost/low-signal, and the *decisions* live entirely in the two seams.

**Prior art:** fresh project, so no in-repo tests exist to pattern-match against; the model's file handling deliberately follows the file-watch load/save pattern already proven by the installed shell's own plugins (which observe, load, and write persistent state the same way), so future contributors find familiar ground.

## Out of Scope

- Multiple notes / creating or deleting notes (single note is the whole product of v1).
- A keybind to summon/hide the note.
- Rich text, markdown rendering, checkboxes, or links.
- Theme-following colors (note stays classic yellow even when the desktop theme changes).
- Undo/history, note search, export/sync (files, cloud, phone).
- Font/style configuration options.
- Automatic multi-monitor layout intelligence (simple on-screen clamping only).
- Packaging, publishing, or submitting upstream to any plugin index — this is a personal tool and a practice artifact.

## Further Notes

**Definition of done (v1):** the note appears on login with saved text, place, and size; I can click in and type; text autosaves continuously; resize by corner-drag; move by drag; scrolls when full; sits behind windows; never crashes or loses data over a week of real use. Multiple notes, keybinds, and anything above are explicitly *not* this bar.

**Primary risk (restated for the implementer):** focus handoff on a background-layer surface — taking keyboard focus on click, releasing on click-away/Escape, and never taking it unprompted. Treat as the riskiest component; the state machine exists so its *logic* is testable even though the focus plumbing is verified manually.

**Context for the implementer:** this spec came out of a structured grilling session; each behavioral rule above was discussed and explicitly chosen (including resizing and move-by-drag being promoted into v1 after the user described their real arrange-then-stretch workflow). Don't "simplify away" the drag/click threshold or the click-away commit — they are load-bearing design decisions, not incidental details.
---

## Amendment — the note becomes a real window (2026-08-31, same day, after live use)

The original layering decision ("desktop background layer, always behind
normal windows") was tested against the real workflow it was written for
and failed it: the user runs **tiled windows most of the time**, so
"behind all windows" meant "invisible and unclickable" — the note could
not be seen or used exactly when it was needed. The user chose, with the
trade-offs stated explicitly, to make the note **a real, compositor-managed
window** that participates in their Hyprland tiling layout.

**Superseded user stories:** 3 (behind windows), 4 (never in the focus
model — a real window is focused, alt-tabbed, and tiled like any other),
13 (exact place is not restored; the compositor places each session's
window, the note's *size* is what persists), 14–19 (arrange/resize are
native Hyprland float/move/resize, not custom gestures — the readability
size floor survives as a native `minimumSize`), 32 (no custom corner
affordance; native resize edges serve it), 34 (the compositor owns
placement, so on-screen stranding is no longer our failure mode).

**Implementation Decisions replaced:**

- *Module shape* — the interaction state machine (seam 2) is **dissolved**.
  Its remaining decisions became native semantics: editing begins when the
  text area takes active focus (click), commits on focus loss (click-away,
  workspace switch) or Escape. The state model (seam 1) is unchanged and
  remains the highest seam.
- *Layering and focus* — replaced wholesale: a quickshell `FloatingWindow`
  titled "Sticky Note". The build's primary flagged risk (background-layer
  keyboard focus) is deleted along with its surface.
- *Persistence* — text unchanged. Geometry is now **observed, never
  driven**: the window is sized once at spawn from the document, then the
  compositor owns it and size changes are recorded back (debounced) so the
  note's last size survives reboots. Position in the document records what
  loads/edits produced; the compositor's placement is per-session.
- *Gesture thresholds* — obsolete; movement and resizing are compositor
  operations.

**Testing Decisions updated:** seam 1 (state model) tests unchanged. Seam
2 tests are deleted with the machine; the commit behavior they covered is
now one binding each (`onActiveFocusChanged`, `Keys.onEscapePressed`).
The corrupt-file fallback, autosave debouncing, external-edit following,
and geometry round-trip all remain under seam 1's tests.

The original spec text above is kept as the record of what was grilled and
why; where it contradicts this amendment, the amendment wins.

---

## Amendment — bold words, as markdown (2026-08-31, same day, after live use)

The user asked for bold ("used to pressing ctrl+b to toggle this"). This
narrows — but does not reverse — the original scope line *"Rich text,
markdown rendering, checkboxes, or links"*: **bold is now in scope, and it
is the only rich-text feature that is.** Markdown rendering exists in the
note for exactly one glyph decision (bold words render bold); checkboxes
and links stay out, and general markdown (headings, italics, lists) is
neither rendered deliberately nor promised to survive a caret mapping.

**The fact that forced the design:** QML's `TextEdit` rich-text API
(`QQuickTextDocument`) exposes only load/save operations to QML — no
`QTextCursor`, no character formats. Live WYSIWYG bold is not possible in
pure QML. So bold lives in the stored text itself as markdown `**`
markers, and the note shows two faces over that one text:

- **Editing** (the text area holds active focus): the raw source, `**word**`
  and all — exactly what is stored, so markers are never a mystery.
- **Idle** (the default, most of a sticky note's life): the source
  rendered as markdown, so bold words appear bold.

Ctrl+B toggles bold over the selection, or the word the caret touches
when nothing is selected (VSCode-style); in open whitespace it inserts
empty `****` markers so the next thing typed renders bold, and pressing
it again inside empty markers removes them.

**A third seam joins the model:** `logic/BoldLogic.mjs` — the toggle
itself and the rendered→source position map used when a click on the
idle view enters editing (the caret must land in the source at the
matching spot). The map refuses to guess when the rendered text cannot
be explained by bold markers alone (a heading, italics, any other
markdown): the caret then falls to the end of the text — a misplaced
caret is fine, a misplaced edit is not. All position decisions live in
the logic module and are covered by node tests; the view only applies
results. The state document stays plain text — human-readable
`"**word**"` in the JSON, per user story 29.

**Persistence, hardened the same day:** the first amendment made geometry
*observed*, and the spawn→tile burst can arrive before the model's
async file read lands. That race could flush defaults over a note the
model had never read — a real data-loss path, found while testing the
bold feature. Fixed in the model's contract and regression-tested there:
**nothing is written before the first read completes, and the first read
adopts the disk document unconditionally.** The view holds geometry
syncs back until the read lands and re-syncs once after, so observed
size is still recorded.

**Testing Decisions updated:** seam 1 (state model) gains the
startup-race regression. The bold seam (toggle + position map) is tested
the same way as the model's logic module — pure node tests, no display,
no pixels. The two-face rendering (markers raw while editing, bold when
idle) is verified on the manual checklist, like all rendering.
