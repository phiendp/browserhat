import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "BrowserhatModel.js" as Model

// Browserhat overlay: the "open this link in which profile?" card.
//
// Driven by the `browserhat` script:
//   omarchy-shell shell summon io.github.phiendp.browserhat '<payload json>'
// Payload: { url, host, targets:[{id,label,sub,glyph,avatar}], selectionFile, doneFile, remember }
// Result: "<target-id>\t<remember 0|1>" written to selectionFile, then doneFile is
// created. Cancelling creates doneFile without writing a selection.
Item {
  id: root

  // Injected by omarchy-shell after the Loader resolves (see shell.qml).
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string url: ""
  property string host: ""
  property var targets: []
  property string selectionFile: ""
  property string doneFile: ""
  property bool rememberAvailable: false
  property bool remember: false
  property bool requestActive: false
  property int selectedIndex: 0
  property bool cursorActive: true

  // Theme tokens: share the [menu] surface so themes that style the Omarchy
  // menu style this overlay too.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md
  property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int avatarSize: Style.space(30)
  property int headerHeight: Style.font.heading + Style.font.caption + Style.spacing.sm
  property int footerHeight: Style.font.caption + Style.spacing.controlPaddingY * 2
  property int cardWidth: Math.min(Style.space(560), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(
    contentMargin * 2 + headerHeight + contentSpacing + rowHeight * Math.max(1, targets.length)
      + (rememberAvailable ? contentSpacing + rowHeight : 0) + contentSpacing + footerHeight,
    panel.height - Style.gapsOut * 2)

  readonly property string pluginId: (root.manifest && root.manifest.id) || "io.github.phiendp.browserhat"

  // ---------------------------------------------------------------- lifecycle

  function open(payloadJson) {
    // A second summon while a request is pending releases the earlier caller
    // (with no selection) so its script does not hang on the done file.
    if (root.requestActive) root.finishDoneFile(root.doneFile)

    var s = Model.parsePayload(payloadJson)
    root.url = s.url
    root.host = s.host
    root.targets = s.targets
    root.selectionFile = s.selectionFile
    root.doneFile = s.doneFile
    root.rememberAvailable = s.rememberAvailable
    root.remember = false
    root.requestActive = !!s.doneFile
    root.selectedIndex = s.initialIndex
    root.cursorActive = true
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Called by the shell on `hide`; treat as cancel so the caller unblocks.
  function close() {
    root.cancel()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function dismiss() {
    root.cancel()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function cancel() {
    if (root.requestActive) root.finishDoneFile(root.doneFile)
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""
    root.opened = false
  }

  // ---------------------------------------------------------------- selection

  function move(delta) {
    var n = root.targets.length
    if (n === 0) return
    root.cursorActive = true
    root.selectedIndex = (root.selectedIndex + delta + n) % n
  }

  function choose(index) {
    if (index < 0 || index >= root.targets.length) return
    var target = root.targets[index]
    var sel = root.selectionFile, done = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""
    if (sel) {
      applyProc.command = ["bash", "-c",
        "printf '%s\\n' " + Util.shellQuote(Model.selectionLine(target, root.remember))
        + " > " + Util.shellQuote(sel) + (done ? "; : > " + Util.shellQuote(done) : "")]
      applyProc.running = true
    }
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  // Dev helper: save a PNG of just the card, e.g. for README previews.
  //   omarchy-shell shell call io.github.phiendp.browserhat snapshot /tmp/browserhat.png
  function snapshot(path) {
    if (!root.opened || !path) return "not open"
    var ok = card.grabToImage(function(result) {
      var saved = result.saveToFile(String(path))
      console.log("browserhat snapshot", saved ? "saved" : "FAILED", path)
    })
    return ok ? "ok" : "grab failed"
  }

  function finishDoneFile(path) {
    if (!path) return
    releaseProc.command = ["bash", "-c", ": > " + Util.shellQuote(path)]
    releaseProc.running = true
  }

  Process { id: applyProc }
  Process { id: releaseProc }

  // ---------------------------------------------------------------- surface

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-browserhat"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var n = root.targets.length
          if (event.key === Qt.Key_Escape) {
            root.dismiss()
          } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            root.move(1)
          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            root.move(-1)
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.choose(root.selectedIndex)
          } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Space) {
            if (root.rememberAvailable) root.remember = !root.remember
          } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            var i = Model.indexForDigit(event.key - Qt.Key_0, n)
            if (i >= 0) root.choose(i)
          } else {
            return
          }
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        // Header: prompt + the full URL so you can see where you're going.
        Column {
          width: parent.width
          spacing: Style.spacing.sm
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.host ? "Open " + root.host + " in…" : "Open a new window in…"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.url !== ""
            text: root.url
            color: root.foreground
            opacity: 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideMiddle
          }
        }

        // Target rows.
        ListView {
          id: rows
          width: parent.width
          height: root.rowHeight * Math.max(1, root.targets.length)
          model: root.targets
          clip: true
          interactive: false
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property int index
            required property var modelData
            readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

            width: rows.width
            height: root.rowHeight
            radius: root.cornerRadius
            color: hasCursor ? root.selectedBackground : "transparent"

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.rowPaddingX
              anchors.rightMargin: Style.spacing.rowPaddingX
              spacing: Style.spacing.lg

              // Hotkey badge.
              Rectangle {
                width: Style.space(22)
                height: Style.space(22)
                anchors.verticalCenter: parent.verticalCenter
                radius: Math.max(2, root.cornerRadius / 2)
                color: "transparent"
                border.width: 1
                border.color: hasCursor ? root.selectedText : root.foreground
                opacity: Model.hotkeyFor(index) ? (hasCursor ? 1 : 0.45) : 0
                Text {
                  anchors.centerIn: parent
                  text: Model.hotkeyFor(index)
                  color: hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              // Avatar (Chrome profile picture) or browser glyph.
              Item {
                width: root.avatarSize
                height: root.avatarSize
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  visible: !modelData.avatar
                  text: modelData.glyph
                  color: hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                }
                Image {
                  id: avatar
                  anchors.fill: parent
                  visible: false
                  source: modelData.avatar ? Util.fileUrl(modelData.avatar) : ""
                  fillMode: Image.PreserveAspectCrop
                  sourceSize: Qt.size(root.avatarSize * 2, root.avatarSize * 2)
                  smooth: true
                }
                Item {
                  id: avatarMask
                  anchors.fill: parent
                  visible: false
                  layer.enabled: true
                  Rectangle { anchors.fill: parent; radius: width / 2 }
                }
                MultiEffect {
                  anchors.fill: parent
                  visible: !!modelData.avatar && avatar.status === Image.Ready
                  source: avatar
                  maskEnabled: true
                  maskSource: avatarMask
                }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(22) - root.avatarSize - parent.spacing * 2
                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: modelData.label
                  color: hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  visible: modelData.sub !== ""
                  text: modelData.sub
                  color: root.foreground
                  opacity: 0.58
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) { root.cursorActive = true; root.selectedIndex = index }
              onClicked: root.choose(index)
            }
          }
        }

        // "Always open <host> here" toggle. Tab/Space flips it; the script
        // writes the rule when the selection comes back with remember=1.
        Rectangle {
          visible: root.rememberAvailable
          width: parent.width
          height: root.rowHeight
          radius: root.cornerRadius
          color: root.remember ? root.selectedBackground : "transparent"
          border.width: 1
          border.color: root.foreground
          opacity: root.remember ? 1 : 0.55

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.spacing.rowPaddingX
            anchors.rightMargin: Style.spacing.rowPaddingX
            spacing: Style.spacing.lg
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.remember ? "󰄲" : "󰄱"
              color: root.remember ? root.selectedText : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              Text {
                textFormat: Text.PlainText
                text: "Always open " + root.host + " here"
                color: root.remember ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                textFormat: Text.PlainText
                text: (root.remember ? "On" : "Off") + " · Tab or Space toggles · adds a rule for this domain"
                color: root.foreground
                opacity: 0.58
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.remember = !root.remember }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "↵ open   1-9 quick open   ↑↓ move   Esc cancel"
          color: root.foreground
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
