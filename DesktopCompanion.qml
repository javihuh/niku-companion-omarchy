import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons

PanelWindow {
  id: root
  property var config: ({})
  property string message: ""
  property bool enabledSetting: false
  readonly property color accent: "#5ac2aa"
  readonly property color foreground: "#dcd6ce"
  readonly property color surface: "#243031"
  readonly property var targetScreen: {
    if (config.monitor) {
      for (var i = 0; i < Quickshell.screens.length; i++)
        if (Quickshell.screens[i].name === config.monitor) return Quickshell.screens[i];
      return null;
    }
    return Quickshell.screens.length ? Quickshell.screens[0] : null;
  }
  readonly property var monitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null

  screen: targetScreen
  visible: enabledSetting && targetScreen !== null && monitor !== null
    && monitor.activeWorkspace !== null && monitor.activeWorkspace.id === (config.workspace || 1)
  anchors { top: true; right: true; bottom: true; left: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "niku-companion"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  Item {
    id: companion
    width: Math.min(370, Math.max(1, root.width - anchors.rightMargin - 12))
    height: bubble.height + tail.height + creature.implicitHeight + Commons.Style.space(8)
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: Math.max(0, Math.min(Number(root.config.marginRight) || 0, root.width - 100))
    anchors.bottomMargin: Math.max(0, Number(root.config.marginBottom) || 0)
    transform: Translate { id: gentleLift }

    SequentialAnimation {
      running: root.visible
      loops: Animation.Infinite
      NumberAnimation { target: gentleLift; property: "y"; from: 0; to: -4; duration: 1900; easing.type: Easing.InOutSine }
      NumberAnimation { target: gentleLift; property: "y"; from: -4; to: 0; duration: 1900; easing.type: Easing.InOutSine }
    }

    Rectangle {
      id: bubble
      anchors.top: parent.top
      anchors.right: parent.right
      width: parent.width
      height: messageText.implicitHeight + 26
      radius: 15
      color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.88)
      border.width: 1
      border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.58)

      Text {
        id: messageText
        anchors.centerIn: parent
        width: parent.width - 36
        text: root.message
        textFormat: Text.PlainText
        color: root.foreground
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }
    }

    Item {
      id: tail
      anchors.top: bubble.bottom
      anchors.right: bubble.right
      anchors.rightMargin: 48
      width: 18
      height: 12
      Rectangle {
        width: 14
        height: 14
        anchors.horizontalCenter: parent.horizontalCenter
        y: -8
        rotation: 45
        color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.88)
        border.width: 1
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
      }
      Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 18
        height: 4
        color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.88)
      }
    }

    Text {
      id: creature
      anchors.top: tail.bottom
      anchors.right: parent.right
      anchors.rightMargin: 12
      text: String(root.config.creature || "ᨳ𐔌՞҂ ˕ ֊՞𐦯ᜊ")
      textFormat: Text.PlainText
      color: root.accent
      font.family: Commons.Style.font.family
      font.pixelSize: 32
      font.weight: Font.DemiBold
    }
  }
}
