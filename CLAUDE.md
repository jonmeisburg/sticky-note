# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single persistent sticky note for the user's Omarchy 4 desktop (Arch + Hyprland + quickshell), shipped as a quickshell plugin. It is a **real compositor-managed window** (a `FloatingWindow` that tiles alongside other windows) — not a desktop overlay. That was a deliberate amendment: the original background-layer design was invisible under the user's tiled workflow. The spec's amendments at the bottom of `docs/spec-sticky-note-v1.md` override anything contradictory above them; the original text is kept as design history.

**Process artifacts are load-bearing.** `docs/spec-sticky-note-v1.md` holds the design and its binding decisions (seams, testing decisions, definition of done). `.scratch/sticky-note/issues/` is the ticket tracker — acceptance checkboxes there are the definition of done, ticked only by someone who demonstrated the behavior. Read both before implementing anything; work one ticket at a time; never tick a checkbox you have not verified. The verify-only tickets (03/04/05) are demonstrated against the live desktop, not the test suite — `.scratch/sticky-note/verify-live.md` is the recipe for driving the note through Hyprland and asserting on the state document (compositor + state-file oracles).

## Commands

```bash
./tests/run.sh                     # full suite: node logic tests + quickshell integration harness
node --test tests/BoldLogic.test.mjs   # single logic test file (no display needed)
node --test tests/*.test.mjs           # all pure-logic tests

# Standalone dev run — hot-reloads on every save, uses a throwaway state file:
STICKY_NOTE_STATE=/tmp/note.json quickshell -p .

# Refresh the installed instance after code changes (the ONLY reliable mechanism):
omarchy restart shell
```

The quickshell integration harness (`tests-harness.qml`, driven by `run.sh`) requires a running Wayland session; the node tests do not.

## Architecture

**Two pure logic modules and one thin view.** All decisions live in `logic/`; the QML only applies results. This is the repo's core contract — code review enforces it.

- `logic/NoteStateLogic.mjs` — the state-document seam: validate/normalize/serialize one JSON document (`text`, `x`, `y`, `width`, `height`), defaults, corrupt-input detection, the size-floor constants (enforced by the window as a native `minimumSize`), plus the small helpers the view delegates to it: window↔paper shadow-margin conversion and `sameState` (deep, key-order-independent document compare). Pure ES module, node-tested.
- `logic/BoldLogic.mjs` — the bold seam: Ctrl+B toggle over selection/word/empty markers, plus `docToSource` (rendered→source caret position map) and `tapCaret` (the map with its fallback). The map **refuses to guess** when rendered text can't be explained by bold markers alone (returns null; other markdown present) — `tapCaret` then lands the caret at end-of-source, so the decision is node-tested and the view only applies results.
- `NoteStateModel.qml` — quickshell `FileView` wrapper: owns load, debounced save, external-edit following, corrupt-file preservation (`note.json.invalid-*`). The startup-race contract lives here: **nothing is written before the first read completes**; the first read adopts the disk document unconditionally, and `loaded` flips only after that adopt — the view's post-read re-sync then records the observed spawn size on top of the adopted document.
- `NoteWindow.qml` / `Service.qml` — the view. `Service.qml` is the manifest entry point; it owns the state file location (`~/.config/sticky-note/note.json`, overridable via `STICKY_NOTE_STATE` for dev/tests) and wires model↔window. Geometry is **observed, never driven**: spawn-sized once from the document, then the compositor owns it and changes are recorded back.

**Bold's two-face design:** the stored text is the single source of truth, with `**` markers inline. While editing (text area has active focus) the raw source shows; when idle the source renders as markdown. Focus semantics are native: editing = active focus; commit = focus loss or Escape. There is no interaction state machine — it was dissolved when the note became a real window (one binding each, per the spec amendment).

**Entry points:** `manifest.json` declares `kinds: ["service"]` → `Service.qml` (mounted by omarchy-shell at startup, which is the login autostart). `shell.qml` is the standalone dev entry (same components, no shell).

## Install / live behavior

The repo is symlinked into the shell: `~/.config/omarchy/plugins/sticky-note` → this directory. The symlink is NOT hot-reloaded (the shell's watcher does not traverse symlinks) — after editing, run `omarchy restart shell`. The standalone `quickshell -p .` loop IS hot-reloading; prefer it for visual iteration. Never point either at the real state file without meaning to; `STICKY_NOTE_STATE` exists so dev/tests can't corrupt the user's note.