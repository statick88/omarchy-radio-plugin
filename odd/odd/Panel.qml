pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Radio panel, laid out like the io.github.ricky.whatsapp panel: a header
// row, a filtered list with an active row, and a bottom composer. Here the
// list holds radio stations, the field above it filters them by name or by
// stream URL/protocol (S3), and the composer is the add-station form (S2)
// that delegates to radio-control.sh so the CLI and the UI share one writer.
Panel {
  id: root
  moduleName: "statick.radio"

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.indexOf("file://") === 0) url = url.substring(7)
    if (url.length > 1 && url.charAt(url.length - 1) === "/") url = url.substring(0, url.length - 1)
    return decodeURIComponent(url)
  }

  readonly property string configDir: Quickshell.env("HOME") + "/.config/omarchy-radio"
  readonly property string stationsPath: configDir + "/stations.conf"
  readonly property string statePath: configDir + "/state"

  // Mirror of stations.conf and of the control script's state file, both
  // kept in sync by the FileView watchers below.
  property var stations: []
  property bool playing: false
  property int currentStation: 1
  property int volume: 80

  // Panel UI state.
  property string search: ""
  property bool formOpen: false
  property string formError: ""
  property bool addBusy: false
  property bool deleteBusy: false
  property var editingId: null
  property int cursor: 0

  readonly property var visibleStations: filterStations()

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function closeForm() { root.formOpen = false; root.formError = ""; root.editingId = null }

  function parseStations(content) {
    var out = []
    var lines = String(content || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (!/^[0-9]+\|/.test(lines[i])) continue
      var parts = lines[i].split("|")
      if (parts.length < 3) continue
      out.push({ id: parseInt(parts[0], 10), name: parts[1], url: parts.slice(2).join("|") })
    }
    root.stations = out
    if (root.cursor >= out.length) root.cursor = Math.max(0, out.length - 1)
  }

  function parseState(content) {
    var map = {}
    var lines = String(content || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^([A-Z_]+)=(.*)$/)
      if (m) map[m[1]] = m[2]
    }
    if (map.CURRENT_STATION !== undefined) {
      var id = parseInt(map.CURRENT_STATION, 10)
      if (!isNaN(id)) root.currentStation = id
    }
    root.playing = map.IS_PLAYING === "true"
    if (map.VOLUME !== undefined) {
      var vol = parseInt(map.VOLUME, 10)
      if (!isNaN(vol)) root.volume = vol
    }
  }

  // S3: filter by station name or by stream URL (protocol, host, path).
  function filterStations() {
    var q = root.search.trim().toLowerCase()
    if (q.length === 0) return root.stations
    var out = []
    for (var i = 0; i < root.stations.length; i++) {
      var s = root.stations[i]
      if (s.name.toLowerCase().indexOf(q) >= 0 || s.url.toLowerCase().indexOf(q) >= 0) out.push(s)
    }
    return out
  }

  function moveCursor(delta) {
    var count = root.visibleStations.length
    if (count === 0) return
    var next = root.cursor + delta
    if (next < 0) next = count - 1
    if (next >= count) next = 0
    root.cursor = next
    listFlick.ensureVisible(next)
  }

  function activateCursor() {
    var station = root.visibleStations[root.cursor]
    if (station) playStation(station.id)
  }

  function runControl(args) {
    controlProcess.running = false
    controlProcess.command = ["sh", root.pluginDir + "/radio-control.sh"].concat(args)
    controlProcess.running = true
  }

  function playStation(id) {
    root.runControl(["play", String(id)])
  }

  // S2/S1: the form only sends what the user typed; validation, the next free
  // id and the atomic write live in radio-control.sh add/update.
  function submitStation() {
    var name = nameField.text.trim()
    var url = urlField.text.trim()
    root.formError = ""
    root.addBusy = true
    addProcess.running = false
    var cmd = root.editingId !== null
      ? ["sh", root.pluginDir + "/radio-control.sh", "update", String(root.editingId), name, url]
      : ["sh", root.pluginDir + "/radio-control.sh", "add", name, url]
    addProcess.command = cmd
    addProcess.running = true
  }

  function deleteStation(id) {
    root.formError = ""
    root.deleteBusy = true
    deleteProcess.running = false
    deleteProcess.command = ["sh", root.pluginDir + "/radio-control.sh", "delete", String(id)]
    deleteProcess.running = true
  }

  FileView {
    id: stationsFile
    path: root.stationsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseStations(text())
    onLoadFailed: root.stations = []
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseState(text())
  }

  Process {
    id: controlProcess
    running: false
    stdout: StdioCollector { id: ctlStdout; waitForEnd: true }
    stderr: StdioCollector { id: ctlStderr; waitForEnd: true }
  }

  Process {
    id: addProcess
    running: false
    stdout: StdioCollector { id: addStdout; waitForEnd: true }
    stderr: StdioCollector { id: addStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.addBusy = false
      root.deleteBusy = false
      if (exitCode === 0) {
        root.formError = ""
        nameField.text = ""
        urlField.text = ""
        root.editingId = null
        root.closeForm()
        return
      }
      var message = String(addStderr.text || addStdout.text || "").trim()
      root.formError = message.length > 0 ? message.replace(/^Error:\s*/, "") : "No se pudo completar la operación"
    }
  }

  Process {
    id: deleteProcess
    running: false
    stdout: StdioCollector { id: delStdout; waitForEnd: true }
    stderr: StdioCollector { id: delStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.deleteBusy = false
      if (exitCode !== 0) {
        var message = String(delStderr.text || delStdout.text || "").trim()
        root.formError = message.length > 0 ? message.replace(/^Error:\s*/, "") : "No se pudo eliminar la estación"
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // The text fields own the keyboard while they have focus, like the
      // WhatsApp composer does.
      blocked: searchField.activeFocus || nameField.activeFocus || urlField.activeFocus

      onCloseRequested: {
        if (root.formOpen) root.closeForm()
        else root.close()
      }
      onTabRequested: function(direction) {
        if (!searchField.activeFocus) searchField.forceActiveFocus()
        else {
          searchField.focus = false
          keyCatcher.forceActiveFocus()
        }
      }
      onMoveRequested: function(dx, dy) { root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        // ── Header ─────────────────────────────────────────────────────
        Item {
          width: parent.width
          implicitHeight: Math.max(headerTitles.implicitHeight, closeButton.height)

          Rectangle {
            id: closeButton
            width: Style.space(26)
            height: Style.space(26)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            radius: 0
            color: closeMouse.containsMouse
              ? Style.hoverFillFor(Color.foreground, Color.accent)
              : Style.normalFillFor(Color.foreground, Color.accent)
            border.color: Color.foreground
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "←"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.formOpen) root.closeForm()
                else root.close()
              }
            }
          }

          Column {
            id: headerTitles
            anchors.left: closeButton.right
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
              text: "Radio"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              text: (function() {
                if (!root.playing) return "Pausado"
                var station = root.stations.find(function(s) { return s.id === root.currentStation })
                return station ? "Reproduciendo · " + station.name : "Reproduciendo · estación " + root.currentStation
              })()
              color: root.playing ? Color.accent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            PanelActionButton {
              iconText: "⏮"
              tooltipText: "Estación anterior"
              onClicked: root.runControl(["prev"])
            }

            PanelActionButton {
              iconText: root.playing ? "⏸" : "▶"
              tooltipText: root.playing ? "Pausar" : "Reproducir"
              onClicked: root.runControl(["toggle"])
            }

            PanelActionButton {
              iconText: "⏭"
              tooltipText: "Siguiente estación"
              onClicked: root.runControl(["next"])
            }

            PanelActionButton {
              iconText: "+"
              tooltipText: root.formOpen ? "Cerrar formulario" : "Agregar estación"
              onClicked: root.formOpen ? root.closeForm() : root.formOpen = true
            }
          }
        }

        // ── Search (S3) ────────────────────────────────────────────────
        TextField {
          id: searchField
          width: parent.width
          placeholderText: "Buscar estaciones…"
          foreground: Color.foreground
          accent: Color.accent
          onTextChanged: root.search = text
          Keys.onEscapePressed: function(event) {
            if (text.length > 0) text = ""
            else root.close()
            event.accepted = true
          }
        }

        Text {
          visible: root.stations.length === 0
          width: parent.width
          text: "Sin estaciones configuradas."
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Text {
          visible: root.stations.length > 0 && root.visibleStations.length === 0
          width: parent.width
          text: "Sin resultados para \"" + root.search + "\""
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        // ── Station list ───────────────────────────────────────────────
        Flickable {
          id: listFlick
          width: parent.width
          height: Math.min(contentHeight, Style.space(210))
          contentHeight: stationColumn.implicitHeight
          interactive: contentHeight > height
          boundsBehavior: Flickable.StopAtBounds
          clip: true

          function ensureVisible(index) {
            var rowHeight = Style.space(30)
            var top = index * rowHeight
            if (top < contentY) contentY = top
            else if (top + rowHeight > contentY + height) contentY = top + rowHeight - height
          }

          Column {
            id: stationColumn
            width: listFlick.width

            Repeater {
              model: root.visibleStations

              delegate: Rectangle {
                id: stationRow
                required property var modelData
                required property int index

                readonly property bool active: modelData.id === root.currentStation
                readonly property bool underCursor: index === root.cursor

                width: stationColumn.width
                height: Style.space(30)
                radius: Style.cornerRadius
                color: active
                  ? Style.selectedFillFor(Color.foreground, Color.accent)
                  : (underCursor || rowMouse.containsMouse)
                    ? Style.hoverFillFor(Color.foreground, Color.accent)
                    : "transparent"
                border.color: active ? Color.accent : "transparent"
                border.width: active ? 1 : 0

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  text: stationRow.active ? "󰄬" : "󰐊"
                  color: stationRow.active ? Color.accent : Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.icon
                }

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(26)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  text: stationRow.modelData.name
                  color: stationRow.active || stationRow.underCursor ? Color.foreground : Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                // Edit/Delete buttons (shown on hover)
                Row {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  visible: rowMouse.containsMouse && !root.addBusy && !root.deleteBusy

                  PanelActionButton {
                    id: editBtn
                    iconText: "✎"
                    tooltipText: "Editar estación"
                    enabled: !root.addBusy && !root.deleteBusy
                    onClicked: {
                      var s = stationRow.modelData
                      root.editingId = s.id
                      nameField.text = s.name
                      urlField.text = s.url
                      root.formOpen = true
                      nameField.focus = true
                    }
                  }

                  PanelActionButton {
                    id: deleteBtn
                    iconText: "🗑"
                    tooltipText: "Eliminar estación"
                    enabled: !root.addBusy && !root.deleteBusy
                    onClicked: {
                      root.deleteStation(stationRow.modelData.id)
                    }
                  }
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: if (containsMouse) root.cursor = stationRow.index
                  onClicked: root.playStation(stationRow.modelData.id)
                }
              }
            }
          }
        }

        PanelSeparator {
          foreground: Color.foreground
        }

        // ── Station form (add / edit) ───────────────────────────────────────────
        Column {
          visible: root.formOpen
          width: parent.width
          spacing: Style.space(6)

          Text {
            id: formTitle
            text: root.editingId !== null ? "Editar estación" : "Agregar estación"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          TextField {
            id: nameField
            width: parent.width
            placeholderText: "Nombre"
            foreground: Color.foreground
            accent: Color.accent
            onAccepted: root.submitStation()
            Keys.onEscapePressed: function(event) {
              if (text.length > 0) text = ""
              else root.closeForm()
              event.accepted = true
            }
          }

          TextField {
            id: urlField
            width: parent.width
            placeholderText: "https://…"
            foreground: Color.foreground
            accent: Color.accent
            onAccepted: root.submitStation()
            Keys.onEscapePressed: function(event) {
              if (text.length > 0) text = ""
              else root.closeForm()
              event.accepted = true
            }
          }

          Row {
            spacing: Style.space(6)

            PanelActionButton {
              id: saveBtn
              iconText: " "
              tooltipText: root.editingId !== null ? "Actualizar estación" : "Guardar estación"
              enabled: nameField.text.trim().length > 0 && urlField.text.trim().length > 0 && !root.addBusy
              onClicked: root.submitStation()
            }

            PanelActionButton {
              iconText: "✕"
              tooltipText: "Cancelar"
              onClicked: root.closeForm()
            }
          }

          Text {
            visible: root.addBusy
            text: "Guardando…"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            visible: root.formError !== ""
            width: parent.width
            text: root.formError
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }

        // ── Volume (unchanged behaviour) ───────────────────────────────
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "🔊"
            font.family: Style.font.family
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
          }

          Slider {
            id: volumeSlider
            width: parent.width - Style.space(70)
            height: Style.space(20)
            from: 0
            to: 100
            value: root.volume
            onMoved: root.runControl(["volume", String(Math.round(value))])
          }

          Text {
            text: root.volume + "%"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.muted
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
