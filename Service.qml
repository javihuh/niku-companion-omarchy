import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/niku-companion"
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/niku-companion"
  property bool directoriesReady: false
  property bool defaultsReady: false
  property bool preferencesReady: false
  property bool stateReady: false
  property var defaults: ({})
  property var preferences: ({})
  property var progress: Model.restore(null)
  property bool dirty: false
  property bool editing: false
  property bool saving: false
  property string storageError: ""
  property double lastTick: Date.now()
  readonly property var config: Model.settings(defaults, preferences)
  readonly property bool ready: directoriesReady && defaultsReady && preferencesReady && stateReady && !storageError
  readonly property bool welcoming: ready && (editing || preferences.setupComplete !== true)
  readonly property bool active: ready && !welcoming && desktop.visible
  readonly property string message: Model.formatMessage(progress.current, preferences.name)

  function readObject(raw) {
    var value = JSON.parse(raw);
    if (!Model.object(value)) throw new Error("Expected a JSON object");
    return value;
  }

  function fail(message) {
    storageError = message;
    console.warn("Niku Companion: " + message);
  }

  function tick(delta) {
    if (!active) return;
    var previousMessage = progress.current;
    progress = Model.advance(progress, delta, Model.periodAt(new Date().getHours()), config);
    dirty = true;
    if (previousMessage !== progress.current) flush();
  }

  function flush() {
    if (!directoriesReady || !stateReady || !dirty) return;
    dirty = false;
    stateFile.setText(JSON.stringify(progress, null, 2) + "\n");
  }

  function saveName(value) {
    if (saving) return;
    saving = true;
    welcome.errorText = "";
    var next = Object.assign({}, preferences, { name: Model.cleanName(value), setupComplete: true });
    preferencesFile.setText(JSON.stringify(next, null, 2) + "\n");
  }

  onActiveChanged: {
    lastTick = Date.now();
    if (active) tick(0);
    else flush();
  }
  Component.onDestruction: flush()

  Process {
    command: ["mkdir", "-p", "--", root.configDir, root.stateDir]
    running: true
    onExited: function(code) {
      if (code === 0) root.directoriesReady = true;
      else root.fail("Could not create local configuration/state directories.");
    }
  }

  FileView {
    path: Qt.resolvedUrl("personality.json").toString().replace(/^file:\/\//, "")
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        root.defaults = root.readObject(text());
        root.defaultsReady = true;
      } catch (error) { root.fail("Invalid bundled personality.json: " + error); }
    }
    onLoadFailed: root.fail("Could not load bundled personality.json.")
  }

  FileView {
    id: preferencesFile
    path: root.directoriesReady ? root.configDir + "/config.json" : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.preferences = root.readObject(text());
        root.preferencesReady = true;
      } catch (error) { root.fail("Invalid config.json; fix the JSON and reload the plugin: " + error); }
    }
    onLoadFailed: function(error) {
      if (!root.directoriesReady) return;
      if (error === FileViewError.FileNotFound) {
        root.preferences = ({});
        root.preferencesReady = true;
      } else root.fail("Could not read config.json: " + error);
    }
    onSaved: {
      if (!root.saving) return;
      root.preferences = root.readObject(text());
      root.saving = false;
      root.editing = false;
    }
    onSaveFailed: function(error) {
      root.saving = false;
      welcome.errorText = "No se pudo guardar el nombre. Revisa los permisos e inténtalo otra vez.";
      console.warn("Niku Companion: config write failed: " + error);
    }
  }

  FileView {
    id: stateFile
    path: root.directoriesReady ? root.stateDir + "/rotation.json" : ""
    atomicWrites: true
    blockWrites: true
    printErrors: false
    onLoaded: {
      if (root.stateReady) return;
      try {
        root.progress = Model.restore(root.readObject(text()));
        root.stateReady = true;
      } catch (error) { root.fail("Invalid rotation.json; back it up and remove it to reset rotation: " + error); }
    }
    onLoadFailed: function(error) {
      if (!root.directoriesReady || root.stateReady) return;
      if (error === FileViewError.FileNotFound) root.stateReady = true;
      else root.fail("Could not read rotation.json: " + error);
    }
    onSaveFailed: function(error) {
      root.dirty = true;
      console.warn("Niku Companion: rotation write failed: " + error);
    }
  }

  Timer {
    interval: 1000
    running: root.active
    repeat: true
    onTriggered: {
      var now = Date.now();
      // Do not count suspended time, clock jumps or a blocked event loop.
      var delta = Math.max(0, Math.min(2000, now - root.lastTick));
      root.lastTick = now;
      root.tick(delta);
    }
  }

  Timer {
    interval: 30000
    running: root.active
    repeat: true
    onTriggered: root.flush()
  }

  DesktopCompanion {
    id: desktop
    config: root.config
    enabledSetting: root.ready && !root.welcoming
    message: root.message
  }

  Welcome {
    id: welcome
    open: root.welcoming
    initialName: String(root.preferences.name || "")
    saving: root.saving
    onAccepted: function(name) { root.saveName(name); }
  }

  IpcHandler {
    target: "io.github.javihuh.companion"
    function configure(): void { root.editing = true; }
    function status(): string {
      return JSON.stringify({ ready: root.ready, active: root.active, welcoming: root.welcoming,
        name: root.preferences.name || "", workspace: root.config.workspace,
        changeMinutes: root.config.changeMinutes, hydrationEveryMinutes: root.config.hydrationEveryMinutes,
        message: root.message, group: root.progress.activeGroup,
        elapsedMs: root.progress.elapsedMs, hydrationElapsedMs: root.progress.hydrationElapsedMs,
        error: root.storageError });
    }
  }
}
