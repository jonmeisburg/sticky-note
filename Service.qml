import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "logic/NoteStateLogic.mjs" as Logic

// Service entry point. Wires the state model to the note window and owns
// the state document's location.
//
// The note lives in ~/.config/sticky-note/note.json: a persistent,
// user-level config location that Omarchy updates never touch (spec user
// story 28), holding one human-readable JSON document (story 29).

Item {
  id: root

  readonly property string configDir: Quickshell.env("HOME") + "/.config/sticky-note"
  // STICKY_NOTE_STATE overrides the document location, so development and
  // tests never touch the real note.
  readonly property string statePath: {
    var override = Quickshell.env("STICKY_NOTE_STATE")
    return (typeof override === "string" && override.length > 0)
      ? override
      : configDir + "/note.json"
  }

  // The config directory must exist — owner-only (0700), since the note's
  // contents are the user's own words — before the model starts writing to
  // it, an existing state file is tightened to owner-only (0600), and a
  // pathologically oversized document is refused (exit 42) so it can never
  // be read into memory whole (Logic.MAX_STATE_BYTES is the only value cap;
  // the document's own values are records, never drivers). The path is
  // handed over only once all of this has succeeded. A failure means the
  // note runs on defaults with persistence unavailable — say so loudly
  // rather than discarding every keystroke in silence.
  property var mkdirProcess: Process {
    command: ["bash", "-c",
      "mkdir -p -m 700 \"$0\" && chmod 700 \"$0\" && " +
      "if [ -f \"$1\" ]; then chmod 600 \"$1\"; fi && " +
      "if [ -f \"$1\" ] && [ \"$(stat -c %s \"$1\")\" -gt $2 ]; then exit 42; fi",
      root.configDir, root.statePath, "" + Logic.MAX_STATE_BYTES]
    onExited: function(exitCode) {
      if (exitCode === 42) {
        console.warn("sticky-note: state document " + root.statePath
          + " exceeds " + Logic.MAX_STATE_BYTES + " bytes; refusing to load it."
          + " The note runs on defaults and will not persist until the file is moved aside")
        return
      }
      if (exitCode !== 0) {
        console.warn("sticky-note: cannot create config dir " + root.configDir
          + " (exit " + exitCode + "); the note will not persist")
        return
      }
      model.path = root.statePath
    }
  }

  Component.onCompleted: mkdirProcess.running = true

  NoteStateModel {
    id: model
  }

  NoteWindow {
    id: noteWindow
    model: model
  }
}