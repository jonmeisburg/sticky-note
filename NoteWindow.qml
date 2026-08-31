import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import "logic/NoteStateLogic.mjs" as Logic

// The view layer: a real, compositor-managed window (the 2026-08-31 spec
// amendment — see docs/spec-sticky-note-v1.md). It contains no decisions of
// its own: placement, tiling, moving, and resizing all belong to Hyprland,
// persistence flows through the state model, and the only interaction
// logic left — when editing begins and commits — is native focus semantics:
//
//   * editing begins when the text area takes active focus (click);
//   * editing commits when the text area loses active focus (click-away,
//     workspace switch) or on Escape;
//   * keystrokes can only land here when the compositor has focused the
//     window, the same contract as every other window.
//
// Geometry is observed, never driven: the window is sized once at spawn
// from the persisted document, then the compositor owns it and every
// change is recorded back so the size survives reboots.

FloatingWindow {
  id: root

  required property var model

  title: "Sticky Note"
  visible: true
  color: "transparent"

  // The paper-yellow body is classic, not themed; the chrome around it
  // (border, scrollbar) follows the desktop theme (spec: Look).
  readonly property color paperColor: "#F7D66E"
  readonly property color inkColor: "#1A1A1A"

  // Room for the drop shadow to spill outside the paper.
  readonly property int shadowMargin: 12

  // The readability floor (spec user story 19) as a native constraint.
  minimumSize: Qt.size(Logic.MIN_WIDTH + shadowMargin * 2,
                       Logic.MIN_HEIGHT + shadowMargin * 2)

  // Spawn size from the persisted document — clamped at load, so a
  // hand-edited absurdity becomes a sane window, not a sliver or a
  // screen-filler. After this the compositor is in charge; we never
  // write geometry back to the window while it lives. (FloatingWindow
  // exposes no x/y at all: placement belongs to Hyprland, so the
  // document's x/y record only what a hand-edit or load produced.)
  Component.onCompleted: {
    implicitWidth = model.state.width + shadowMargin * 2
    implicitHeight = model.state.height + shadowMargin * 2
  }

  // Record compositor-driven size changes (tiling shuffles, resizes)
  // back into the model, debounced, so the document reflects the note's
  // last real size for the next launch. updateGeometry's no-op compare
  // keeps the spawn sizing above from dirtying.
  onWidthChanged: syncGeometry()
  onHeightChanged: syncGeometry()

  function syncGeometry() {
    model.updateGeometry(
      model.state.x, model.state.y,
      width - shadowMargin * 2, height - shadowMargin * 2
    )
  }

  // --- the paper ----------------------------------------------------------

  // Soft shadow, faked with three stacked offset rounds rather than a blur
  // effect: cheap and static, off the render loop's hot path.
  Repeater {
    model: [
      { dx: 0, dy: 2, o: 0.14 },
      { dx: 0, dy: 5, o: 0.10 },
      { dx: 0, dy: 8, o: 0.07 },
    ]
    delegate: Rectangle {
      required property var modelData
      x: paper.x + modelData.dx
      y: paper.y + modelData.dy
      width: paper.width
      height: paper.height
      radius: paper.radius + 3
      color: "black"
      opacity: modelData.o
    }
  }

  Rectangle {
    id: paper
    anchors.fill: parent
    anchors.margins: root.shadowMargin
    radius: 6
    color: root.paperColor

    // The editing cue: a theme-accent border while the text cursor is in
    // the note (spec user story 9).
    border.width: textEdit.activeFocus ? 2 : 0
    border.color: Color.accent

    Behavior on border.width { NumberAnimation { duration: 100 } }

    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: 10
      clip: true
      contentWidth: width
      contentHeight: textEdit.implicitHeight
      boundsBehavior: Flickable.StopAtBounds

      TextArea.flickable: TextArea {
        id: textEdit
        width: flick.width
        wrapMode: TextArea.Wrap
        color: root.inkColor
        selectionColor: Color.accent
        selectedTextColor: root.inkColor
        font.pixelSize: Style.font.heading
        background: null
        padding: 0

        // Commit on focus loss: click-away, workspace switch, focus moved
        // by the compositor. Flushes the debounce so the tail of the
        // session is never lost (spec user story 10).
        onActiveFocusChanged: if (!activeFocus) root.model.saveNow()

        // Escape: the keyboard-only commit. Drops the cursor while the
        // window keeps compositor focus; the focus-loss handler flushes.
        Keys.onEscapePressed: paper.forceActiveFocus()

        // External state changes (another editor, hand-edited file) land
        // here; typing flows the other way through onTextChanged.
        Connections {
          target: root.model
          function onStateChanged() {
            if (textEdit.text !== root.model.state.text) {
              textEdit.text = root.model.state.text
            }
          }
        }

        onTextChanged: root.model.setText(text)
      }

      ScrollBar.vertical: ScrollBar {
        id: scrollBar
        implicitWidth: 6
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
          radius: 3
          color: scrollBar.pressed ? Color.accent
            : scrollBar.hovered ? Color.foreground : Color.muted
          opacity: 0.7
        }
      }
    }
  }
}