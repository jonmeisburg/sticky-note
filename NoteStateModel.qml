import QtQuick
import Quickshell.Io
import "logic/NoteStateLogic.mjs" as Logic

// Seam 1 — the note's state model.
//
// Owns load, save, and file-watch-reload for the single state document
// (text + geometry). Every decision — what a valid document is, what the
// defaults are, how positions clamp back on-screen — is delegated to
// NoteStateLogic.mjs so it stays testable without a display (spec:
// Implementation Decisions).
//
// The file contract: one human-readable JSON document. Autosave is a
// continuous pattern, not a "save" concept: every change — text or
// geometry — debounces a write; commit (focus loss, Escape) flushes
// anything pending so the final keystrokes of an editing session are
// never lost.

Item {
  id: root

  /// Where the state document lives. Empty until the owner wires it up.
  property string path: ""

  /// Current screen size, for on-screen clamping at load and on monitor
  /// changes. 0 means "unknown" — the logic modules leave state untouched.
  property real screenW: 0
  property real screenH: 0

  /// Current state: { text, x, y, width, height }. Replaced (never mutated)
  /// so bindings on it re-evaluate.
  property var state: Logic.defaults()

  /// True when in-memory state has changes not yet on disk.
  readonly property bool dirty: root._dirty

  /// Tunable: how long a burst of typing settles before it hits the disk.
  property int saveDebounceMs: 500

  property bool _dirty: false
  // True between our own write and the file watcher's notification for it,
  // so onFileChanged can tell "we changed it" from "someone else did".
  property bool _selfWrite: false

  onScreenWChanged: reclamp()
  onScreenHChanged: reclamp()

  // Teardown (shell reload, logout) flushes anything the debounce still
  // holds, so a quit inside the debounce window costs no data.
  Component.onDestruction: saveNow()

  onPathChanged: {
    if (path !== "") Qt.callLater(function() { if (fileView.path !== "") fileView.reload() })
  }

  function reclamp() {
    var next = Logic.clampToScreen(state, screenW, screenH)
    if (JSON.stringify(next) !== JSON.stringify(state)) {
      state = next
      // The clamped geometry differs from the disk copy; dirty + debounce
      // so it actually persists (and adopt() honors it as a pending local
      // change) instead of silently diverging.
      _dirty = true
      saveDebounce.restart()
    }
  }

  // --- mutations ---------------------------------------------------------

  function setText(text) {
    if (state.text === text) return
    state = {
      text: text,
      x: state.x, y: state.y,
      width: state.width, height: state.height,
    }
    _dirty = true
    saveDebounce.restart()
  }

  // Geometry moves during a drag arrive many times a second; they update
  // in-memory state and ride the same debounced autosave rather than
  // hitting the disk per mouse move. The view flushes with saveNow()
  // when the gesture settles.
  function updateGeometry(x, y, width, height) {
    var next = {
      text: state.text,
      x: Math.round(x), y: Math.round(y),
      width: Math.round(width), height: Math.round(height),
    }
    if (JSON.stringify(next) === JSON.stringify(state)) return
    state = next
    _dirty = true
    saveDebounce.restart()
  }

  /// Flush any pending change to disk. Safe to call when clean: a no-op.
  function saveNow() {
    saveDebounce.stop()
    if (path === "" || !_dirty) return
    _dirty = false
    // Our own write will trip the file watcher; adopt() must not re-enter
    // on our own bytes (no reload churn, and no clamping/adopting of a
    // stale view while a gesture is in flight).
    _selfWrite = true
    fileView.setText(Logic.serializeState(state))
  }

  // --- load / follow -------------------------------------------------------

  // A document we wrote ourselves parses back to exactly `state`; external
  // edits parse to something new and are adopted (state and file must never
  // silently diverge). While a local edit is pending, the local edit wins.
  function adopt(raw) {
    var result = Logic.parseState(raw)
    if (!result.ok) {
      handleCorrupt(raw)
      return
    }
    if (_dirty) return
    var next = Logic.clampToScreen(result.state, screenW, screenH)
    if (JSON.stringify(next) !== JSON.stringify(state)) state = next
  }

  // A malformed document means a lost note, not a broken desktop (spec user
  // story 30): fall back to defaults, keep the original bytes aside as
  // `note.json.invalid-<stamp>` so the user can hand-repair them, and put a
  // fresh valid document in place. The preserve write goes through the same
  // FileView plumbing as the recovery write, in order, at detection time —
  // never through a shell command (quoting breaks on odd paths) and never
  // as a deferred rename that could carry a later recovery save away.
  function handleCorrupt(raw) {
    if (_dirty) return
    state = Logic.defaults()
    _dirty = false
    var stamp = new Date().getTime()
    preserveView.path = path + ".invalid-" + stamp
    preserveView.setText(raw)
    _selfWrite = true
    fileView.setText(Logic.serializeState(state))
  }

  Timer {
    id: saveDebounce
    interval: root.saveDebounceMs
    onTriggered: root.saveNow()
  }

  FileView {
    id: fileView
    path: root.path
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.adopt(text())
    onLoadFailed: {
      // Absent or unreadable file: safe defaults, nothing written until
      // the user actually changes something.
      if (!root._dirty) root.state = Logic.defaults()
    }
    onFileChanged: {
      // Skip the reload for our own writes; the next watch event is then
      // by definition an external change and reloads as usual.
      if (root._selfWrite) {
        root._selfWrite = false
        return
      }
      reload()
    }
  }

  // Write-only view for preserving corrupt originals; see handleCorrupt.
  FileView {
    id: preserveView
    watchChanges: false
    atomicWrites: true
    printErrors: true
  }
}