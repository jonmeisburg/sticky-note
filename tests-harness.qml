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
          NoteStateModel {}", root)
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

      // The commit contract (spec user story 10): when editing commits
      // (focus loss, Escape), the pending tail of the debounce must land
      // immediately — the last keystrokes of a session are never held
      // for the debounce window. Flushed explicitly (saveNow), the way
      // the view's commit binding does. FileView.setText writes
      // asynchronously, so the read waits for the write to land — but
      // the wait costs the test nothing: saveNow stops the debounce
      // before writing, so the flush is the only possible writer and no
      // wait can let the debounce mask a broken flush.
      enqueue({ name: "a commit flush writes the pending tail immediately", run: function() {
        model.setText("flushed tail")
        model.saveNow()
        assertTruthy(!model.dirty, "the commit flush left the model clean")
        wait(500, function() {
          sh("cat '" + statePath + "'", function(out2) {
            var parsed = Logic.parseState(out2)
            assertEq(parsed.ok && parsed.state.text, "flushed tail",
              "the pending tail reached disk before the debounce window closed")
            proceed()
          })
        })
      }})

      // The other half of user story 10 — the reboot path: teardown
      // (shell reload, logout) runs Component.onDestruction: saveNow(),
      // so a tail the debounce still holds lands even when the process
      // dies inside the debounce window. Destroying the model here IS
      // that teardown: no explicit flush, no debounce wait first.
      enqueue({ name: "teardown flushes a tail the debounce still holds", run: function() {
        var m = Qt.createQmlObject("
          import QtQuick
          import \".\"
          NoteStateModel {}", root)
        m.path = statePath
        wait(600, function() { // the first read adopted the on-disk document
          m.setText("teardown tail")
          m.destroy()
          wait(500, function() {
            sh("cat '" + statePath + "'", function(out2) {
              var parsed = Logic.parseState(out2)
              assertEq(parsed.ok && parsed.state.text, "teardown tail",
                "the teardown flush wrote the tail the debounce still held")
              proceed()
            })
          })
        })
      }})

      // The startup race, as it happens live: a note is on disk, a fresh model
      // is pointed at it, and a save lands before the async file read
      // completes. Two contracts must hold at once:
      //   * the pre-read save is a no-op — a document the model never read
      //     must not be clobbered (the write guard);
      //   * the view's re-sync rides the loaded flip, which the model turns
      //     only after the adopt, so the observed spawn size is recorded on
      //     top of the adopted document (the ordering).
      // The pre-read save is flushed explicitly (m.saveNow()) instead of
      // racing the 500ms debounce against the read: same guard, but the
      // test stays deterministic — at flush time the read has not even
      // started. The re-sync is the view's, minus the window: a
      // Connections on the model recording the observed size.
      enqueue({ name: "startup race: a save before the first read cannot clobber the file", run: function() {
        var racePath = tmpDir + "/race.json"
        var seed = JSON.stringify({ text: "precious", x: 10, y: 10, width: 100, height: 100 })
        sh("printf '%s' '" + seed + "' > '" + racePath + "'", function() {
          var m = Qt.createQmlObject("
            import QtQuick
            import \".\"
            NoteStateModel {
              id: m
              // the observed spawn size, as the spawn -> tile burst delivers it
              property int observedW: 400
              property int observedH: 500
              // the view's re-sync, without the view: record the observed
              // size once the first read has landed
              Connections {
                target: m
                function onLoadedChanged() {
                  if (m.loaded) m.updateGeometry(m.state.x, m.state.y, m.observedW, m.observedH)
                }
              }
            }", root)
          m.path = racePath
          // Observed geometry before the read has even started, then the
          // flush the debounce would have fired.
          m.updateGeometry(10, 10, 400, 500)
          m.saveNow()
          wait(400, function() { // the read has landed; the post-read write has not
            sh("cat '" + racePath + "'", function(out1) {
              assertEq(out1, seed, "pre-read save never touched the file")
              assertEq(m.state.text, "precious", "disk text survived the startup race")
              assertEq(m.state.width, 400, "re-sync recorded the observed size over the adopted document")
              assertTruthy(m.dirty, "the recorded size is a pending write")
              wait(800, function() { // the debounce lands the pending write
                sh("cat '" + racePath + "'", function(out2) {
                  var parsed = Logic.parseState(out2)
                  assertEq(parsed.state, { text: "precious", x: 10, y: 10, width: 400, height: 500 },
                    "the observed size was persisted over the adopted document")
                  assertTruthy(!m.dirty, "the race left the model clean")
                  m.destroy()
                  proceed()
                })
              })
            })
          })
        })
      }})

      runNext()
    })
  }
}