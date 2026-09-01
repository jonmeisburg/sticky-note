import QtQuick
import Quickshell.Io
import "logic/NoteStateLogic.mjs" as Logic

// Seam 1 — the note's state model.
//
// Owns load, save, and file-watch-reload for the single state document
// (text + geometry). Every decision — what a valid document is, what the
// defaults are, when two documents compare equal — is delegated to
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

  /// Current state: { text, x, y, width, height }. Replaced (never mutated)
  /// so bindings on it re-evaluate.
  property var state: Logic.defaults()

  /// True when in-memory state has changes not yet on disk.
  readonly property bool dirty: root._dirty

  /// Tunable: how long a burst of typing settles before it hits the disk.
  property int saveDebounceMs: 500

  /// True once the first read attempt has finished (a load or a load
  /// failure) and its result is in `state`. The flip rides after the
  /// adopt, so the view's post-read re-sync records the observed spawn
  /// size on top of the adopted document, not underneath it. Nothing is
  /// written before the flip: a startup burst of observed geometry can
  /// arrive before the async file read lands, and flushing it then would
  /// clobber the note with defaults. The view also waits on this to start
  /// recording geometry.
  readonly property bool loaded: root._loaded

  property bool _dirty: false
  property bool _loaded: false
  property bool _firstRead: true
  // True between our own write and the file watcher's notification for it,
  // so onFileChanged can tell "we changed it" from "someone else did".
  property bool _selfWrite: false

  // Teardown (shell reload, logout) flushes anything the debounce still
  // holds, so a quit inside the debounce window costs no data.
  Component.onDestruction: saveNow()

  onPathChanged: {
    if (path !== "") Qt.callLater(function() { if (fileView.path !== "") fileView.reload() })
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

  // Compositor-driven size changes (a tiling shuffle, a resize) arrive
  // many times a second; they update in-memory state and ride the same
  // debounced autosave rather than hitting the disk per change. The view
  // flushes with saveNow() when editing commits.
  function updateGeometry(x, y, width, height) {
    var next = {
      text: state.text,
      x: Math.round(x), y: Math.round(y),
      width: Math.round(width), height: Math.round(height),
    }
    if (Logic.sameState(next, state)) return
    state = next
    _dirty = true
    saveDebounce.restart()
  }

  /// Flush any pending change to disk. Safe to call when clean: a no-op.
  /// Also a no-op before the first read: writing a document the model has
  /// never read is exactly the startup race that loses notes.
  function saveNow() {
    saveDebounce.stop()
    if (path === "" || !_loaded || !_dirty) return
    _dirty = false
    // Our own write will trip the file watcher; adopt() must not re-enter
    // on our own bytes (no reload churn, no re-adopting a document we
    // just wrote).
    _selfWrite = true
    fileView.setText(Logic.serializeState(state))
  }

  // --- load / follow -------------------------------------------------------

  // A document we wrote ourselves parses back to exactly `state`; external
  // edits parse to something new and are adopted (state and file must never
  // silently diverge). While a local edit is pending, the local edit wins —
  // with one exception: the first read must adopt regardless of pending
  // dirt, because before it there is no local truth to prefer. The only
  // pre-read change is geometry observed between spawn and load; the first
  // read retires that delta, and the view's re-sync — which rides the
  // `loaded` flip, i.e. after this adopt — records the observed size on
  // top, so nothing observed is lost.
  function adopt(raw, initial) {
    var result = Logic.parseState(raw)
    if (!result.ok) {
      handleCorrupt(raw, initial)
      return
    }
    if (_dirty && !initial) return
    if (!Logic.sameState(result.state, state)) state = result.state
    if (initial) _dirty = false
  }

  // A malformed document means a lost note, not a broken desktop (spec user
  // story 30): fall back to defaults, keep the original bytes aside as
  // `note.json.invalid-<stamp>` so the user can hand-repair them, and put a
  // fresh valid document in place. The preserve write goes through the same
  // FileView plumbing as the recovery write, in order, at detection time —
  // never through a shell command (quoting breaks on odd paths) and never
  // as a deferred rename that could carry a later recovery save away.
  function handleCorrupt(raw, initial) {
    if (_dirty && !initial) return
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
    onLoaded: {
      var initial = root._firstRead
      root._firstRead = false
      root.adopt(text(), initial)
      // Flipped after the adopt: the view's re-sync rides loadedChanged,
      // so it must see the adopted document — otherwise it records the
      // observed size underneath it and the adopt discards it (spec:
      // observed size is still recorded).
      root._loaded = true
    }
    onLoadFailed: {
      // Absent or unreadable file: safe defaults, nothing written until
      // the user actually changes something. State settles before the
      // flip, for the same reason as onLoaded.
      root._firstRead = false
      if (!root._dirty) root.state = Logic.defaults()
      root._loaded = true
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