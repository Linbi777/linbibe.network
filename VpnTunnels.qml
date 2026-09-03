import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

// Independent Amnezia / WireGuard toggles. They do not take each other down.
Item {
  id: root
  required property var hostPanel
  property string page: "amnezia" // "amnezia" | "wireguard"
  property bool pageActive: false

  readonly property string amneziaHelper: Qt.resolvedUrl("bin/amnezia-ctl").toString().replace(/^file:\/\//, "")
  readonly property string wgHelper: Qt.resolvedUrl("bin/wg-ctl").toString().replace(/^file:\/\//, "")

  property var amnezia: ({ detected: false, connected: false, summary: "", servers: [], error: "" })
  property var wireguard: ({ detected: false, connected: false, summary: "", profiles: [], error: "" })
  property bool amneziaBusy: false
  property bool wgBusy: false
  property string amneziaDetail: ""
  property string wgDetail: ""

  implicitHeight: content.implicitHeight
  width: parent ? parent.width : implicitWidth

  function refreshAmnezia() {
    if (!amneziaProc.running) amneziaProc.running = true
  }

  function refreshWg() {
    if (!wgProc.running) wgProc.running = true
  }

  function refresh() {
    refreshAmnezia()
    refreshWg()
  }

  function parseJson(raw, fallback) {
    try {
      return JSON.parse(String(raw || "").trim())
    } catch (error) {
      return fallback
    }
  }

  function toggleAmnezia() {
    if (amneziaBusy || amneziaAction.running) return
    var connected = amnezia.connected === true
    var args = connected ? ["disconnect"] : ["connect", "0"]
    amneziaBusy = true
    amneziaDetail = connected ? "Disconnecting…" : "Connecting…"
    amneziaAction.command = [amneziaHelper].concat(args)
    amneziaAction.running = true
  }

  function toggleWg(uuid) {
    if (wgBusy || wgAction.running) return
    var profile = null
    var profiles = wireguard.profiles || []
    for (var i = 0; i < profiles.length; i++) {
      if (!uuid || profiles[i].uuid === uuid) { profile = profiles[i]; break }
    }
    if (!profile) return
    wgBusy = true
    wgDetail = profile.active ? "Disconnecting…" : "Connecting…"
    wgAction.command = profile.active
      ? [wgHelper, "disconnect", profile.uuid]
      : [wgHelper, "connect", profile.uuid]
    wgAction.running = true
  }

  onPageActiveChanged: {
    if (pageActive) {
      refresh()
      poll.restart()
    } else {
      poll.stop()
    }
  }

  Component.onCompleted: if (pageActive) refresh()

  Timer {
    id: poll
    interval: 4000
    repeat: true
    running: root.pageActive
    onTriggered: root.refresh()
  }

  Process {
    id: amneziaProc
    command: [root.amneziaHelper, "status"]
    stdout: StdioCollector { id: amneziaOut; waitForEnd: true }
    onExited: function() {
      var parsed = root.parseJson(amneziaOut.text, root.amnezia)
      root.amnezia = parsed
      if (!root.amneziaBusy) root.amneziaDetail = parsed.error || ""
    }
  }

  Process {
    id: wgProc
    command: [root.wgHelper, "status"]
    stdout: StdioCollector { id: wgOut; waitForEnd: true }
    onExited: function() {
      var parsed = root.parseJson(wgOut.text, root.wireguard)
      root.wireguard = parsed
      if (!root.wgBusy) root.wgDetail = parsed.error || ""
    }
  }

  Process {
    id: amneziaAction
    command: []
    stdout: StdioCollector { id: amneziaActOut; waitForEnd: true }
    stderr: StdioCollector { id: amneziaActErr; waitForEnd: true }
    onExited: function(code) {
      root.amneziaBusy = false
      var parsed = root.parseJson(amneziaActOut.text, null)
      if (parsed) root.amnezia = parsed
      if (code !== 0) {
        root.amneziaDetail = String((parsed && parsed.error) || amneziaActErr.text || "Amnezia action failed").trim()
      } else {
        root.amneziaDetail = ""
      }
      root.refreshAmnezia()
    }
  }

  Process {
    id: wgAction
    command: []
    stdout: StdioCollector { id: wgActOut; waitForEnd: true }
    stderr: StdioCollector { id: wgActErr; waitForEnd: true }
    onExited: function(code) {
      root.wgBusy = false
      var parsed = root.parseJson(wgActOut.text, null)
      if (parsed) root.wireguard = parsed
      if (code !== 0) {
        root.wgDetail = String((parsed && parsed.error) || wgActErr.text || "WireGuard action failed").trim()
      } else {
        root.wgDetail = ""
      }
      root.refreshWg()
    }
  }

  Column {
    id: content
    width: parent.width
    spacing: Style.space(14)

    TunnelRow {
      visible: root.page === "amnezia"
      width: parent.width
      title: "Amnezia VPN"
      subtitle: {
        if (root.amneziaBusy) return root.amneziaDetail || "Working…"
        if (root.amneziaDetail !== "") return root.amneziaDetail
        if (root.amnezia.connected) return root.amnezia.summary || "Connected"
        if (root.amnezia.detected) return "Disconnected"
        return "AmneziaVPN is not available"
      }
      active: root.amnezia.connected === true
      busy: root.amneziaBusy
      enabled: root.amnezia.detected === true
      onToggled: root.toggleAmnezia()
    }

    Repeater {
      model: root.page === "wireguard" ? (root.wireguard.profiles || []) : []
      delegate: TunnelRow {
        required property var modelData
        width: parent.width
        title: modelData.name
        subtitle: {
          if (root.wgBusy) return root.wgDetail || "Working…"
          if (root.wgDetail !== "") return root.wgDetail
          return modelData.active ? "Connected" : "Disconnected"
        }
        active: modelData.active === true
        busy: root.wgBusy
        enabled: true
        onToggled: root.toggleWg(modelData.uuid)
      }
    }

    Text {
      visible: root.page === "wireguard" && (root.wireguard.profiles || []).length === 0
      width: parent.width
      text: "No WireGuard profiles in NetworkManager"
      color: Qt.darker(root.hostPanel.bar.foreground, 1.4)
      font.family: root.hostPanel.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  component TunnelRow: Item {
    id: row
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool busy: false
    property bool enabled: true
    signal toggled()

    implicitHeight: Math.max(labels.implicitHeight, power.implicitHeight)
    opacity: enabled ? 1 : 0.55

    Column {
      id: labels
      anchors.left: parent.left
      anchors.right: power.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)

      Text {
        width: parent.width
        text: row.title
        color: root.hostPanel.bar.foreground
        font.family: root.hostPanel.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: row.subtitle
        color: Qt.darker(root.hostPanel.bar.foreground, 1.4)
        font.family: root.hostPanel.bar.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    ToggleSwitch {
      id: power
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: row.active
      busy: row.busy
      interactive: row.enabled && !row.busy
      foreground: root.hostPanel.bar.foreground
      onToggled: row.toggled()
    }
  }
}
