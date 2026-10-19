pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui

// Bar entry for the radio plugin. Mirrors io.github.ricky.whatsapp's bar
// widget: one shared Ui.WidgetButton whose glyph carries the live badge
// (station number while playing) instead of a bespoke icon component.
//
// Playing state, station and volume come from radio-control.sh's state file
// through the FileView below, so the badge and the panel always agree with
// what is actually playing (a Process started from the panel can never flip
// this widget's state by itself).
Ui.BarWidget {
  id: root
  moduleName: "statick.radio"

  readonly property string statePath: Quickshell.env("HOME") + "/.config/omarchy-radio/state"

  // Initial values come from the widget settings (the shell's read-only
  // contract, `setting()`); the state file overrides them as soon as it
  // loads, and on every change afterwards.
  property int station: Math.max(1, Math.min(20, setting("station", 1)))
  property int volume: Math.max(0, Math.min(100, setting("volume", 80)))
  property bool playing: false

  function parseState(content) {
    var map = {}
    var lines = String(content || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^([A-Z_]+)=(.*)$/)
      if (m) map[m[1]] = m[2]
    }
    if (map.IS_PLAYING !== undefined) root.playing = map.IS_PLAYING === "true"
    if (map.CURRENT_STATION !== undefined) {
      var id = parseInt(map.CURRENT_STATION, 10)
      if (!isNaN(id)) root.station = id
    }
    if (map.VOLUME !== undefined) {
      var vol = parseInt(map.VOLUME, 10)
      if (!isNaN(vol)) root.volume = vol
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseState(text())
    onLoadFailed: {
      root.playing = false
      root.station = root.setting("station", 1)
      root.volume = root.setting("volume", 80)
    }
  }

  // Panel loader
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      // The panel's internal bindings resolve against `bar` once the loader
      // finishes; a second pass settles them, as the reference plugin does.
      Qt.callLater(root.injectPanel)
    }
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Ui.WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰝚" + (root.playing ? " " + root.station : "")
    foreground: root.playing
      ? Color.accent
      : (root.bar ? root.bar.barForeground : Color.foreground)
    tooltipText: {
      var state = root.playing ? "▶ Reproduciendo estación " + root.station : "⏸ Pausado"
      return "Radio · " + state + " · " + root.volume + "%"
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.togglePanel()
    }
  }
}
