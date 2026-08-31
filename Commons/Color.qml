// Development-only stand-in for the shell's qs.Commons Color singleton.
//
// Inside the real Omarchy shell, `qs` aliases the shell's own directory and
// this file is never consulted — the note gets the live theme palette.
// When the plugin is run standalone (dev-shell.qml), quickshell aliases
// `qs` to THIS directory instead, and these neutral defaults keep the
// chrome renderable for iteration.

pragma Singleton
import QtQuick

QtObject {
  property color foreground: "#cacccc"
  property color background: "#101315"
  property color accent: "#a6bfc6"
  property color urgent: "#a55555"
  property color muted: "#707880"
}