import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import "logic/NoteStateLogic.mjs" as Logic
import "logic/BoldLogic.mjs" as Bold

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
  minimumSize: Qt.size(Logic.paperToWindowSize(Logic.MIN_WIDTH, shadowMargin),
                       Logic.paperToWindowSize(Logic.MIN_HEIGHT, shadowMargin))

  // Spawn size from the persisted document; the readability floor above is
  // the only size limit — placement belongs to Hyprland, so a hand-edited
  // document's x/y are recorded, not applied. After this the compositor is
  // in charge; we never write geometry back to the window while it lives.
  // (FloatingWindow exposes no x/y at all: the document's x/y record only
  // what a hand-edit or load produced.)
  Component.onCompleted: {
    implicitWidth = Logic.paperToWindowSize(model.state.width, shadowMargin)
    implicitHeight = Logic.paperToWindowSize(model.state.height, shadowMargin)
  }

  // Record compositor-driven size changes (tiling shuffles, resizes)
  // back into the model, debounced, so the document reflects the note's
  // last real size for the next launch. updateGeometry's no-op compare
  // keeps the spawn sizing above from dirtying. Held back until the model
  // has read the file: a spawn → tile burst can land before the async
  // load, and recording it then is the race that wipes notes — the model
  // gates the write, this keeps the dirt from ever forming.
  onWidthChanged: if (model.loaded) syncGeometry()
  onHeightChanged: if (model.loaded) syncGeometry()

  // Once the first read lands — after the model has adopted the disk
  // document, which is what the model's loaded flip signals — whatever
  // geometry the compositor settled on during the wait is recorded in one
  // re-sync: observed size is not lost to the hold-back above.
  Connections {
    target: model
    function onLoadedChanged() { if (model.loaded) syncGeometry() }
  }

  function syncGeometry() {
    model.updateGeometry(
      model.state.x, model.state.y,
      Logic.windowToPaperSize(width, shadowMargin),
      Logic.windowToPaperSize(height, shadowMargin)
    )
  }

  // Which face is showing. Editing begins only through the tap catcher
  // (which must make the editor visible before it can take focus) and
  // ends on every focus loss. Driven by an explicit flag rather than
  // activeFocus alone: while idle the editor must not paint at all —
  // the raw source and the rendered markdown overlap otherwise, and
  // with bold markers in the text the two faces diverge and smear.
  property bool editing: false

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

    // The note has two faces over one text. While editing, the raw
    // markdown source is shown — "**word**" and all — because QML
    // exposes no rich-text cursor API, so bold lives in the text, not
    // in character formats. While idle (the default, most of a sticky
    // note's life), the source is rendered: bold words appear bold.
    // Ctrl+B toggles the markers (spec amendment, bold request).
    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: 10
      clip: true
      contentWidth: width
      contentHeight: root.editing
        ? textEdit.implicitHeight : idleView.implicitHeight
      boundsBehavior: Flickable.StopAtBounds

      TextArea.flickable: TextArea {
        id: textEdit
        width: flick.width
        visible: root.editing
        textFormat: TextEdit.PlainText
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
        onActiveFocusChanged: if (!activeFocus) {
          root.editing = false
          root.model.saveNow()
        }

        // Escape: the keyboard-only commit. Drops the cursor while the
        // window keeps compositor focus; the focus-loss handler flushes.
        Keys.onEscapePressed: paper.forceActiveFocus()

        // Ctrl+B: toggle bold over the selection, or the word the caret
        // touches (BoldLogic owns every position decision; the view only
        // applies the result).
        Keys.onPressed: (event) => {
          if (event.key === Qt.Key_B
              && (event.modifiers & Qt.ControlModifier)) {
            const r = Bold.toggleBold(text, selectionStart, selectionEnd)
            text = r.text
            if (r.selStart === r.selEnd) cursorPosition = r.selStart
            else select(r.selStart, r.selEnd)
            event.accepted = true
          }
        }

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

      // The idle face: the note rendered as markdown. Untouchable —
      // it never takes focus or selection; the tap catcher below hands
      // clicks over to the editor. The text binding is cleared while
      // editing so the markdown is not re-parsed on every keystroke.
      TextArea {
        id: idleView
        y: 0
        width: flick.width
        visible: !root.editing
        text: root.editing ? "" : textEdit.text
        textFormat: TextEdit.MarkdownText
        readOnly: true
        selectByMouse: false
        activeFocusOnPress: false
        cursorVisible: false
        wrapMode: TextArea.Wrap
        color: root.inkColor
        font.pixelSize: Style.font.heading
        background: null
        padding: 0
      }

      // Click-to-edit while idle: map the tap to a caret position in the
      // source through the rendered document. BoldLogic owns the whole
      // decision (tapCaret): the mapping, and the fallback to end-of-text
      // when the rendering cannot be explained by bold markers alone
      // (other markdown, e.g. a heading) — never a wrong mid-text position.
      MouseArea {
        enabled: !root.editing
        width: flick.width
        height: Math.max(flick.height, idleView.implicitHeight)

        onPressed: (mouse) => {
          const docPos = idleView.positionAt(mouse.x, mouse.y)
          textEdit.cursorPosition = Bold.tapCaret(
            textEdit.text, idleView.getText(0, idleView.length), docPos)
          // The editor must be visible before it can take focus.
          root.editing = true
          textEdit.forceActiveFocus()
        }
      }

      // The scrollbar is just a floating handle — no track. The handle
      // only paints when there is real content to scroll for, judged
      // from the flickable itself rather than the bar's own `size`:
      // a size a hair under 1 otherwise paints a full-height sliver
      // down the right edge that reads as a stray line, not a
      // scrollbar.
      ScrollBar.vertical: ScrollBar {
        id: scrollBar
        implicitWidth: 6
        policy: ScrollBar.AsNeeded
        background: null
        contentItem: Rectangle {
          radius: 3
          color: scrollBar.pressed ? Color.accent
            : scrollBar.hovered ? Color.foreground : Color.muted
          opacity: flick.contentHeight > flick.height + 8 ? 0.7 : 0

          Behavior on opacity { NumberAnimation { duration: 100 } }
        }
      }
    }
  }
}