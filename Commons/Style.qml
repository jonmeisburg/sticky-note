// Development-only stand-in for the shell's qs.Commons Style singleton.
// See Commons/Color.qml for why this exists.

pragma Singleton
import QtQuick

QtObject {
  readonly property QtObject font: QtObject {
    readonly property string family: "sans-serif"
    readonly property int heading: 16
  }
}