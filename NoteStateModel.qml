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
// continuous pattern, not a "save" concept: text changes debounce a
// write; geometry changes write immediately; commit flushes anything
// pending so the final keystrokes of an editing session are never lost.

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

  onScreenWChanged: reclamp()
  onScreenHChanged: reclamp()

  onPathChanged: {
    if (path !== "") Qt.callLater(function() { if (fileView.path !== "") fileView.reload() })
  }

  function reclamp() {
    var next = Logic.clampToScreen(state, screenW, screenH)
    if (JSON.stringify(next) !== JSON.stringify(state)) state = next
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

  // Called when a gesture settles (drag release, resize release): geometry
  // changes are rare and deliberate, so they persist immediately.
  function setGeometry(x, y, width, height) {
    var next = {
      text: state.text,
      x: Math.round(x), y: Math.round(y),
      width: Math.round(width), height: Math.round(height),
    }
    if (JSON.stringify(next) === JSON.stringify(state)) return
    state = next
    _dirty = true
    saveNow()
  }

  /// Flush any pending change to disk. Safe to call when clean: a no-op.
  function saveNow() {
    saveDebounce.stop()
    if (path === "" || !_dirty) return
    _dirty = false
    fileView.setText(Logic.serializeState(state))
  }

  // --- load / follow -------------------------------------------------------

  // A document we wrote ourselves parses back to exactly `state`; external
  // edits parse to something new and are adopted (state and file must never
  // silently diverge). While a local edit is pending, the local edit wins.
  function adopt(raw) {
    var result = Logic.parseState(raw)
    if (!result.ok) {
      handleCorrupt()
      return
    }
    if (_dirty) return
    var next = Logic.clampToScreen(result.state, screenW, screenH)
    if (JSON.stringify(next) !== JSON.stringify(state)) state = next
  }

  // A malformed document means a lost note, not a broken desktop (spec user
  // story 30): fall back to defaults, and keep the original bytes aside so
  // the user can hand-repair instead of having them overwritten.
  function handleCorrupt() {
    if (_dirty) return
    state = Logic.defaults()
    _dirty = false
    var stamp = new Date().getTime()
    var command = "mv '" + path + "' '" + path + ".invalid-" + stamp + "' 2>/dev/null"
    _preserveComponent.command = ["bash", "-c", command]
    _preserveComponent.running = true
  }

  property var _preserveComponent: Process {
    onExited: function(exitCode) { running = false }
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
    onFileChanged: reload()
  }
}