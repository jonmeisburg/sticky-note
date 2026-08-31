// Integration harness for the sticky-note state model (seam 1).
//
// Drives NoteStateModel.qml against a real temp file inside a live
// quickshell instance and asserts only externally observable behavior
// (spec, Testing Decisions): what is on disk after a mutation, what state
// is loaded from a given file, and that a corrupt file falls back to
// defaults without losing the original bytes.
//
// tests/run.sh starts this config, waits for the verdict line, and kills
// the instance.

import Quickshell
import Quickshell.Io
import QtQuick
import "logic/NoteStateLogic.mjs" as Logic

ShellRoot {
  id: root

  // The model under test. Path is bound once the temp dir exists.
  property string statePath: ""
  property var model: null
  property var failures: []
  property string tmpDir: ""

  // Fixed pretend screen; clamping itself is pure logic already covered by
  // the node tests — here we only exercise the model's file behavior.
  readonly property real screenW: 1920
  readonly property real screenH: 1080

  Component.onCompleted: start()

  // --- step plumbing -------------------------------------------------------

  property var queue: []
  property var queueIndex: 0

  function enqueue(step) { queue.push(step) }

  function runNext() {
    if (queueIndex >= queue.length) {
      verdict()
      return
    }
    var step = queue[queueIndex++]
    console.log("SNTEST STEP: " + step.name)
    step.run()
  }

  function proceed() { wait(400, runNext) }

  // Wait, then continue. Gives FileView loads, inotify watches, and
  // debounced writes time to land without the steps racing them.
  function wait(ms, then) {
    stepTimer.interval = ms
    stepTimer.then = then
    stepTimer.restart()
  }

  property QtObject stepTimer: Timer {
    id: stepTimer
    property var then: null
    onTriggered: { var cb = then; then = null; if (cb) cb() }
  }

  // One reusable shell-command runner: deliver trimmed stdout to `then`.
  property var shThen: null
  property QtObject shProc: Process {
    stdout: StdioCollector { id: shStdio }
    onExited: function(exitCode) {
      var cb = root.shThen
      root.shThen = null
      if (cb) cb(String(shStdio.text || "").trim(), exitCode)
    }
  }

  function sh(command, then) {
    shThen = then
    shProc.command = ["bash", "-c", command]
    shProc.running = true
  }

  // --- assertions ---------------------------------------------------------

  function fail(message) {
    failures.push(message)
    console.log("SNTEST FAIL: " + message)
  }

  function assertEq(actual, expected, label) {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      fail(label + " — expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual))
    } else {
      console.log("SNTEST PASS: " + label)
    }
  }

  function assertTruthy(value, label) {
    if (!value) fail(label)
    else console.log("SNTEST PASS: " + label)
  }

  function verdict() {
    if (root.failures.length === 0) console.log("SNTEST VERDICT: ALL PASS")
    else console.log("SNTEST VERDICT: FAIL (" + root.failures.length + " failures)")
    console.log("SNTEST DONE")
  }

  // --- the test ------------------------------------------------------------

  function start() {
    sh("mktemp -d /tmp/sticky-note-test.XXXXXX", function(out) {
      tmpDir = out
      statePath = out + "/note.json"

      enqueue({ name: "defaults when the state file is absent", run: function() {
        model = Qt.createQmlObject("
          import QtQuick
          import \".\"
          NoteStateModel {
            screenW: root.screenW
            screenH: root.screenH
          }", root)
        model.path = statePath
        wait(600, function() {
          assertEq(model.state, Logic.defaults(), "missing file yields defaults")
          sh("[ -f '" + statePath + "' ] && echo exists || echo absent", function(out2) {
            assertEq(out2, "absent", "no state file is created before the first save")
            proceed()
          })
        })
      }})

      enqueue({ name: "explicit save writes the document to disk", run: function() {
        model.setText("hello world")
        model.saveNow()
        wait(500, function() {
          sh("cat '" + statePath + "'", function(out2) {
            var parsed = Logic.parseState(out2)
            assertEq(parsed.ok && parsed.state.text, "hello world", "saved file holds the typed text")
            assertEq(parsed.ok && parsed.state.width, Logic.defaults().width, "saved file holds the geometry")
            proceed()
          })
        })
      }})

      enqueue({ name: "typing autosaves after the debounce, with no explicit save", run: function() {
        model.setText("second thought")
        wait(1200, function() {
          sh("cat '" + statePath + "'", function(out2) {
            var parsed = Logic.parseState(out2)
            assertEq(parsed.ok && parsed.state.text, "second thought", "debounced autosave wrote the new text")
            proceed()
          })
        })
      }})

      enqueue({ name: "geometry changes ride the same debounced autosave", run: function() {
        model.updateGeometry(700, 300, 500, 800)
        wait(1200, function() {
          sh("cat '" + statePath + "'", function(out2) {
            var parsed = Logic.parseState(out2)
            assertEq(parsed.ok && parsed.state.x, 700, "geometry change reached the document")
            assertEq(parsed.ok && parsed.state.width, 500, "size change reached the document")
            assertEq(parsed.ok && parsed.state.text, "second thought", "geometry change kept the text")
            proceed()
          })
        })
      }})

      enqueue({ name: "external edits to the file are followed", run: function() {
        sh("printf '%s' '" + JSON.stringify({
          text: "external edit", x: 500, y: 300, width: 350, height: 450
        }) + "' > '" + statePath + "'", function() {
          wait(1000, function() {
            assertEq(model.state.text, "external edit", "model adopted externally written text")
            assertEq(model.state.x, 500, "model adopted externally written geometry")
            proceed()
          })
        })
      }})

      enqueue({ name: "a corrupt file falls back to defaults and keeps the original", run: function() {
        sh("printf '%s' 'GARBAGE {{{ not json' > '" + statePath + "'", function() {
          wait(1000, function() {
            assertEq(model.state, Logic.defaults(), "corrupt file yields defaults, no crash")
            sh("ls '" + tmpDir + "'", function(out2) {
              assertTruthy(out2.indexOf("note.json.invalid-") !== -1, "corrupt original preserved as note.json.invalid-*")
              sh("cat '" + tmpDir + "'/note.json.invalid-*", function(out3) {
                assertEq(out3, "GARBAGE {{{ not json", "preserved file still holds the original bytes")
                proceed()
              })
            })
          })
        })
      }})

      enqueue({ name: "the model recovers by writing a fresh valid document", run: function() {
        model.setText("recovered")
        model.saveNow()
        wait(500, function() {
          sh("cat '" + statePath + "'", function(out2) {
            var parsed = Logic.parseState(out2)
            assertEq(parsed.ok && parsed.state.text, "recovered", "fresh save after corruption is a valid document")
            proceed()
          })
        })
      }})

      runNext()
    })
  }
}