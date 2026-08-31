// Development entry point for running the note standalone:
//
//   STICKY_NOTE_STATE=/tmp/note.json quickshell -p .
//
// The real shell loads this plugin through Service.qml (manifest entry
// point); this file exists so the exact same components can be run and
// iterated on outside the shell, against a throwaway state file.

import Quickshell
import QtQuick
import "."

ShellRoot {
  Service {}
}