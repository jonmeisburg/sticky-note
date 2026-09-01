import QtQuick
import Quickshell
import Quickshell.Io
import "."

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

  // The config directory must exist before the model starts writing to
  // it, so the path is handed over only once mkdir has succeeded. A
  // failed mkdir means the note runs on defaults with persistence
  // unavailable — say so loudly rather than discarding every keystroke
  // in silence.
  property var mkdirProcess: Process {
    command: ["bash", "-c", "mkdir -p \"$0\"", root.configDir]
    onExited: function(exitCode) {
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