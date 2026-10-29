import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons

PanelWindow {
  id: root
  property bool open: false
  property string initialName: ""
  property bool saving: false
  property string errorText: ""
  signal accepted(string name)

  visible: open
  implicitWidth: Math.min(480, screen ? screen.width : 480)
  implicitHeight: form.implicitHeight + 48
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "niku-companion-welcome"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  onOpenChanged: {
    if (open) {
      nameField.text = initialName;
      errorText = "";
      Qt.callLater(function() { nameField.forceActiveFocus(); });
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 20
    color: "#243031"
    border.color: "#5ac2aa"
    border.width: 1

    Column {
      id: form
      anchors.centerIn: parent
      width: parent.width - 48
      spacing: 16

      Text {
        width: parent.width
        text: "ᨳ𐔌՞҂ ˕ ֊՞𐦯ᜊ"
        color: "#5ac2aa"
        font.family: Commons.Style.font.family
        font.pixelSize: 32
        horizontalAlignment: Text.AlignHCenter
      }
      Text {
        width: parent.width
        text: "Niku Companion\n¿Cómo quieres que te llame?"
        textFormat: Text.PlainText
        color: "#dcd6ce"
        font.family: Commons.Style.font.family
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }
      TextField {
        id: nameField
        width: parent.width
        placeholderText: "Tu nombre"
        maximumLength: 60
        enabled: !root.saving
        onAccepted: if (!root.saving) root.accepted(text)
      }
      Text {
        width: parent.width
        text: "Tu nombre se guarda solo en este equipo. Puedes cambiarlo después."
        color: "#dcd6ce"
        font.family: Commons.Style.font.family
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
      }
      Button {
        width: parent.width
        text: root.saving ? "Guardando…" : "Guardar"
        enabled: !root.saving
        onClicked: root.accepted(nameField.text)
      }
      Button {
        width: parent.width
        text: "Continuar sin nombre"
        enabled: !root.saving
        onClicked: root.accepted("")
      }
      Text {
        width: parent.width
        visible: text.length > 0
        text: root.errorText
        color: "#ffb4ab"
        font.pixelSize: 13
        wrapMode: Text.WordWrap
      }
    }
  }
}
